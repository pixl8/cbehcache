component extends="coldbox.system.cache.AbstractCacheBoxProvider" implements="coldbox.system.cache.providers.ICacheProvider"  accessors=true serializable=false {

	property name="cache";

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
		, keyClass                       = "java.lang.String"
		, valueClass                     = "java.lang.Object"
		, memoryType                     = "heap"
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
					application.ehCacheManager.close();
					application.delete( "ehCacheManager" );
				}
			}
		}
	}

	function validateConfiguration() {
		StructAppend( variables.configuration, variables.DEFAULTS );

		for( var key in variables.DEFAULTS ){
			if( NOT len( variables.configuration[ key ] ) ){
				variables.configuration[ key ] = variables.DEFAULTS[ key ];
			}
		}
	}

	function registerCache() {
		var mngr  = _getManager();
		var cache = mngr.createCache( getName(), _getConfigForEhCache() );

		setCache( cache );
	}


// CORE CACHE METHODS
	function get( required objectKey ){
		return variables.cache.get( arguments.objectKey );
	}

	any function set(
		  required any    objectKey
		, required any    object
		,          any    timeout           = 0  // ignored
		,          any    lastAccessTimeout = 0  // ignored
		,          struct extra             = {} // ignored
	){
		variables.cache.put( arguments.objectKey, arguments.object );

		return this;
	}

	any function getOrSet(
		  required any objectKey
		, required any produce
		,          any timeout           = 0
		,          any lastAccessTimeout = 0
		,          any extra             = {}
	){
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
		return [];
	}

	boolean function lookup( required objectKey ){
		return variables.cache.containsKey( arguments.objectKey );
	}

	function clearAll(){
		variables.cache.clear();
		return this;
	}

	boolean function clear( required objectKey ){
		variables.cache.remove( arguments.objectKey );
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

// UTILITIES
	private any function _obj( required string className ) {
		return CreateObject( "java", arguments.className, _getLib() )
	}

	private any function _class( required string className ) {
		return _obj( arguments.className ).class;
	}

	private array function _getLib() {
		return DirectoryList( ExpandPath( "/preside/system/modules/cbehcache/lib" ), false, "path", "*.jar" );
	}

	private any function _getManager() {
		if ( !StructKeyExists( application, "ehCacheManager" ) ) {
			lock type="exclusive" name="ehCacheManagerLoad" timeout=5 {
				if ( !StructKeyExists( application, "ehCacheManager" ) ) {
					var manager = _obj( "org.ehcache.config.builders.CacheManagerBuilder" ).newCacheManagerBuilder().using( _getStatsService() ).build();

					manager.init();

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

		return _getResourcePoolBuilder().heap( JavaCast( "long", cfmlConfig.maxObjects ) ).build();
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

}