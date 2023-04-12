component extends="coldbox.system.cache.AbstractCacheBoxProvider" implements="coldbox.system.cache.providers.ICacheProvider"  accessors=true serializable=false {

	property name="cache";
	property name="jGroupsCluster";

// BEGIN: Coldbox templateCache gumf
	property name="elementCleaner";
	property name="eventURLFacade";

	this.VIEW_CACHEKEY_PREFIX 	= "cbox_view-";
	this.EVENT_CACHEKEY_PREFIX 	= "cbox_event-";
// END: Coldbox templateCache gumf

	variables.DEFAULTS = {
		  objectDefaultTimeout           = 60
		, objectDefaultLastAccessTimeout = 0
		, useLastAccessTimeouts          = false
		, maxObjects                     = 1000
		, maxSizeInMb                    = 0
		, keyClass                       = "java.lang.String"
		, valueClass                     = "java.lang.Object"
		, storage                        = "heap" // heap / offheap / disk currently supported
		, persistent                     = false // for disk only
		, cluster                        = false
		, clusterName                    = "cbehcache"
		, propagateDeletes               = true
		, propagatePuts                  = false
		, lowerCaseKeys                  = false
	};


// CONSTRUCTION, CONFIGURATION + SHUTDOWN
	function init(){
		super.init();

		setElementCleaner( new coldbox.system.cache.util.ElementCleaner( this ) );
		setEventURLFacade( new coldbox.system.cache.util.EventURLFacade( this ) );

		return this;
	}

	function configure(){
		lock name="EHCacheProvider.config.#variables.cacheID#" type="exclusive" throwontimeout="true" timeout="30"{
			validateConfiguration();
			registerCache();

			variables.enabled          = true;
			variables.reportingEnabled = true;
		}

		return this;
	}

	function shutdown(){
		if ( StructKeyExists( application, "ehCacheManager" ) ) {
			lock type="exclusive" name="ehCacheManagerShutdown" timeout=5 {
				if ( StructKeyExists( application, "ehCacheManager" ) ) {
					try {
						application.ehCacheManager.close();
					} catch( any e ) {}

					application.delete( "ehCacheManager" );
				}
			}
		}
	}

	function validateConfiguration() {
		StructAppend( variables.configuration, variables.DEFAULTS, false );

		for( var key in variables.DEFAULTS ){
			if( NOT len( variables.configuration[ key ] ) ){
				variables.configuration[ key ] = variables.DEFAULTS[ key ];
			}
		}

		if ( !variables.configuration.useLastAccessTimeouts ) {
			variables.configuration.objectDefaultLastAccessTimeout = 0;
		}

		if ( ArrayFind( [ "nonheap", "disk" ], variables.configuration.storage ) ) {
			if ( variables.configuration.valueClass == "java.lang.Object" ) {
				throw( type="ehcacheprovider.bad.config", message="The [#getName()#] cache is incorrectly configured. When using [#variables.configuration.storage#] storage, you must specify a serializable value class, e.g. 'java.lang.String', or 'struct', 'array' or 'query'. See cbehcache README for documentation on how to set the valueClass for your cache." );
			}
		}

		if ( variables.configuration.cluster ) {
			if ( !variables.configuration.propagateDeletes && !variables.configuration.propagatePuts ) {
				variables.configuration.cluster = false;
			} else if ( !Len( Trim( variables.configuration.clusterName ) ) ) {
				throw( type="ehcacheprovider.bad.config", message="The [#getName()#] cache is incorrectly configured. When enabling clustering, clusterName cannot be empty." );
			}
		} else {
			variables.configuration.propagateDeletes = false;
			variables.configuration.propagatePuts    = false;
		}
	}

	function registerCache() {
		var mngr  = _getManager();

		try {
			cache = mngr.createCache( getName(), _getConfigForEhCache() );
		}
		catch ( any e ) {
			if ( e.message contains "UNINITIALIZED" ) {
				mngr.init();
				try {
					cache = mngr.createCache( getName(), _getConfigForEhCache() );
				} catch ( any ee ) {
					var detail = serializeJSON( {
						  cacheName         = getName()
						, configuration     = getConfiguration()
						, managerStatus     = mngr.getStatus().toString()
						, originalException = ee.type ?: ""
						, originalMessage   = ee.message
					} );
					throw( "An EHCache cache could not be registered.", "cbehcache.cache.registration", detail );
				}
			} else {
				rethrow;
			}
		}
		catch ( any e ) {
			if ( e.message contains "already exists" ) {
				return;
			} else {
				rethrow;
			}
		}

		setCache( cache );
	}

	function getJGroupsCluster() {
		return variables.jgroupsCluster ?: setupCluster();
	}

	function setupCluster() {
		var conf       = getConfiguration();
		var wirebox    = getColdbox().getWirebox();
		var theCluster = wirebox.getInstance( dsl="cbjgroups:cluster:" & conf.clusterName );

		setJGroupsCluster( theCluster );

		return theCluster;
	}


// CORE CACHE METHODS
	function get( required objectKey ){
		arguments.objectKey = _fixObjectKeyCase( arguments.objectKey );
		try {
			return variables.cache.get( arguments.objectKey );
		} catch( any e ) {
			// cache unavailable, probably due to shutdown
		}
	}

	any function set(
		  required any    objectKey
		, required any    object
		,          any    timeout           = 0  // ignored
		,          any    lastAccessTimeout = 0  // ignored
		,          struct extra             = {} // ignored
	){
		arguments.objectKey = _fixObjectKeyCase( arguments.objectKey );
		try {
			variables.cache.put( arguments.objectKey, arguments.object );
			if ( variables.configuration.propagatePuts && _isTrue( arguments.propagate ?: true ) ) {
				_runClusterEvent( "set", {
					  objectKey = arguments.objectKey
					, object    = arguments.object
				} );
			}
		} catch( any e ) {
			// cache unavailable, probably due to shutdown
		}
		return this;
	}

	any function getOrSet(
		  required any objectKey
		, required any produce
		,          any timeout           = 0
		,          any lastAccessTimeout = 0
		,          any extra             = {}
	){
		arguments.objectKey = _fixObjectKeyCase( arguments.objectKey );
		var value = get( arguments.objectKey );

		if ( IsNull( local.value ) ) {
			value = arguments.produce();
			set(
				  objectKey         = arguments.objectKey
				, object            = value
				, timeout           = arguments.timeout
				, lastAccessTimeout = arguments.lastAccessTimeout
				, extra             = arguments.extra
			)
		}

		return value;
	}

	array function getKeys(){
		var cacheKeys = [];
		var iterator  = variables.cache.iterator();

		while( iterator.hasNext() ) {
			cacheKeys.append( iterator.next().getKey() );
		}

		return cacheKeys;
	}

	boolean function lookup( required objectKey ){
		arguments.objectKey = _fixObjectKeyCase( arguments.objectKey );
		try {
			return variables.cache.containsKey( arguments.objectKey );
		} catch( any e ) {
			// cache unavailable, probably due to shutdown
		}
	}

	function clearAll(){
		try {
			variables.cache.clear();

			if ( variables.configuration.propagateDeletes && _isTrue( arguments.propagate ?: true ) ) {
				_runClusterEvent( "clearall" );
			}
		} catch( any e ) {
			// cache unavailable, probably due to shutdown
		}
		return this;
	}

	boolean function clear( required any objectKey ){
		arguments.objectKey = _fixObjectKeyCase( arguments.objectKey );
		try {
			variables.cache.remove( arguments.objectKey );
			if ( variables.configuration.propagateDeletes && _isTrue( arguments.propagate ?: true ) ) {
				_runClusterEvent( "clear", { objectKey=arguments.objectKey } );
			}
		} catch( any e ) {
			// cache unavailable, probably due to shutdown
		}
		return true;
	}

// HOUSE KEEPING
	function getStats(){
		return new cbehcache.models.EhCacheStats( _getStatsService().getCacheStatistics( getName() ) );
	}
	function clearStatistics(){
		getStats().clearStatistics();
	}

	numeric function getSize(){
		return getStats().getObjectCount();
	}

	function setColdbox( required any coldbox ) {
		variables.coldbox = arguments.coldbox;
	}

	function getColdbox() {
		return variables.coldbox;
	}


// NOT IMPLEMENTING
	function getObjectStore(){}

	struct function getStoreMetadataReport(){
		return {};
	}
	struct function getStoreMetadataKeyMap(){
		return {};
	}
	struct function getStoreMetadataKeyMap(){
		return {};
	}
	struct function getCachedObjectMetadata( required objectKey ){
		return {};
	}
	function reap(){
		return this;
	}
	function expireAll(){
		return this;
	}
	function expireObject( required objectKey ){
		return this;
	}

	boolean function isexpired( required objectKey ) {
		return false;
	}

	function getQuiet( required objectKey ){
		return get( arguments.objectKey );
	}
	boolean function lookupQuiet( required objectKey ){
		return lookup( arguments.objectKey );
	}
	boolean function clearQuiet( required objectKey ){
		return clear( arguments.objectKey );
	}
	any function setQuiet(
		  required any    objectKey
		, required any    object
		,          any    timeout           = 0
		,          any    lastAccessTimeout = 0
		,          struct extra             = {}
	){
		return set(
			  objectKey         = arguments.objectKey
			, object            = arguments.object
			, timeout           = arguments.timeout
			, lastAccessTimeout = arguments.lastAccessTimeout
			, extra             = arguments.extra
		);
	}

	function clearByKeySnippet( required keySnippet, boolean regex=false, boolean async=false ){
		clearAll();
	}

// UTILITIES
	private any function _obj( required string className ) {
		return CreateObject( "java", arguments.className, _getLib() )
	}

	private string function _fixObjectKeyCase( required string objectKey ) {
		if ( variables.configuration.lowerCaseKeys ) {
			return LCase( arguments.objectKey );
		}
		return arguments.objectKey;
	}

	private any function _class( required string className ) {
		switch( arguments.className ) {
			case "lucee.runtime.type.Struct":
			case "struct":
				return ( {} ).getClass();
			case "lucee.runtime.type.Array":
			case "array":
				return ( [] ).getClass();
			case "lucee.runtime.type.Query":
			case "query":
				return ( QueryNew('') ).getClass();
		}
		return _obj( arguments.className ).class;
	}

	private array function _getLib() {
		return DirectoryList( ExpandPath( GetDirectoryFromPath(GetCurrentTemplatePath()) & "../lib" ), false, "path", "*.jar" );
	}

	private any function _getManager() {
		if ( !StructKeyExists( application, "ehCacheManager" ) ) {
			lock type="exclusive" name="ehCacheManagerLoad" timeout=5 {
				if ( !StructKeyExists( application, "ehCacheManager" ) ) {
					_closeAbandonedManagers(); // there can be only one

					var storage = _obj( "java.io.File" ).init( _getFileStorageDirectory() );
					var builder = _obj( "org.ehcache.config.builders.CacheManagerBuilder" );
					var manager = builder.newCacheManagerBuilder()
					                     .using( _getStatsService() )
					                     .with( builder.persistence( storage ) )
					                     .build();

					manager.init();

					_storeManagerInServerScopeToAvoidBadShutdownIssues( manager );

					application.ehCacheManager = manager;
				}
			}
		}

		return application.ehCacheManager;
	}

	private any function _getStatsService() {
		if ( !StructKeyExists( application, "ehCacheStatsService" ) ) {
			lock type="exclusive" name="ehCacheStatsServiceLoad" timeout=5 {
				if ( !StructKeyExists( application, "ehCacheStatsService" ) ) {
					application.ehCacheStatsService = _obj( "org.ehcache.impl.internal.statistics.DefaultStatisticsService" );
				}
			}
		}

		return application.ehCacheStatsService;
	}

	private string function _getFileStorageDirectory() {
		var dir = getTempDirectory() & "/ehcache/" & _getAppName();

		DirectoryCreate( dir, true, true );

		return dir;
	}

	private any function _getConfigForEhCache() {
		var cfmlConfig    = getConfiguration();
		var keyClass      = _class( cfmlConfig.keyClass );
		var valueClass    = _class( cfmlConfig.valueClass );

		return _getConfigBuilder( keyClass, valueClass, _getResourcePoolConfig() )
		       .withExpiry( _getExpiryPolicyConfig() )
		       .build();
	}

	private any function _getConfigBuilder( keyClass, valueClass, resourcePool ) {
		return _obj( "org.ehcache.config.builders.CacheConfigurationBuilder" ).newCacheConfigurationBuilder( keyClass, valueClass, resourcePool );
	}

	private any function _getResourcePoolBuilder() {
		return _obj( "org.ehcache.config.builders.ResourcePoolsBuilder" );
	}

	private any function _getExpiryPolicyBuilder() {
		return _obj( "org.ehcache.config.builders.ExpiryPolicyBuilder" );
	}

	private any function _getResourcePoolConfig() {
		var cfmlConfig = getConfiguration();

		switch( cfmlConfig.storage ) {
			case "offheap":
				return _configureOffHeapStorage( cfmlConfig.maxSizeInMb );

			case "disk":
				return _configureDiskStorage( cfmlConfig.maxSizeInMb, cfmlConfig.persistent );
		}

		// heap default
		return _configureHeapStorage( cfmlConfig.maxObjects, cfmlConfig.maxSizeInMb );
	}

	private any function _configureHeapStorage( maxObjects, maxSizeInMb ) {
		if ( arguments.maxObjects ) {
			return _getResourcePoolBuilder().heap( JavaCast( "long", arguments.maxObjects ) ).build();
		}

		return _getResourcePoolBuilder().heap( JavaCast( "long", arguments.maxSizeInMb ), _obj( "org.ehcache.config.units.MemoryUnit" ).MB ).build();
	}

	private any function _configureOffHeapStorage( maxSizeInMb ) {
		return _getResourcePoolBuilder().offheap( JavaCast( "long", arguments.maxSizeInMb ), _obj( "org.ehcache.config.units.MemoryUnit" ).MB ).build();
	}

	private any function _configureDiskStorage( maxSizeInMb, persistent ) {
		return _getResourcePoolBuilder().newResourcePoolsBuilder().disk( JavaCast( "long", arguments.maxSizeInMb ), _obj( "org.ehcache.config.units.MemoryUnit" ).MB, arguments.persistent ).build();
	}

	private any function _getExpiryPolicyConfig() {
		var cfmlConfig = getConfiguration();

		if ( !cfmlConfig.objectDefaultLastAccessTimeout + cfmlConfig.objectDefaultTimeout ) {
			return _getExpiryPolicyBuilder().noExpiration();
		}

		if ( cfmlConfig.useLastAccessTimeouts ) {
			var timeout = cfmlConfig.objectDefaultLastAccessTimeout ? cfmlConfig.objectDefaultLastAccessTimeout : cfmlConfig.objectDefaultTimeout;

			return _getExpiryPolicyBuilder().timeToIdleExpiration( _obj( "java.time.Duration" ).ofMinutes( cfmlConfig.objectDefaultTimeout ) );
		}

		return _getExpiryPolicyBuilder().timeToLiveExpiration( _obj( "java.time.Duration" ).ofMinutes( cfmlConfig.objectDefaultTimeout ) );
	}

	private boolean function _isTrue( required any value ) {
		return IsBoolean( arguments.value ) && arguments.value;
	}

	private void function _runClusterEvent( required string event, struct args={} ) {
		args.cacheName = getName();

		getJGroupsCluster().runEvent(
			  event          = "cbehcache:ehCacheClusterListener.#arguments.event#"
			, eventArguments = args
		);
	}

	private string function _getAppName() {
		var appMeta = getApplicationMetadata();

		return appMeta.name ?: Hash( ExpandPath( "/" ) );
	}

	private void function _storeManagerInServerScopeToAvoidBadShutdownIssues( required any manager ) {
		var appName = _getAppName();
		server.ehCacheManagers = server.ehCacheManagers ?: {};
		server.ehCacheManagers[ appName ] = server.ehCacheManagers[ appName ] ?: [];

		ArrayAppend( server.ehCacheManagers[ appName ], arguments.manager );
	}

	private void function _closeAbandonedManagers() {
		var appName  = _getAppName();
		var managers = server.ehCacheManagers[ appName ] ?: [];

		for( var i=ArrayLen( managers ); i>0; i-- ) {
			try {
				managers[ i ].close();
			} catch( any e ) {
				// ignore, already closed
			}

			ArrayDeleteAt( managers, i );
		}
	}
}
