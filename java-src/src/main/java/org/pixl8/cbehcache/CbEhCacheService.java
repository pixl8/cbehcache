package org.pixl8.cbehcache;

import java.io.File;
import java.time.Duration;
import java.lang.ClassNotFoundException;

import org.ehcache.core.EhcacheManager;
import org.ehcache.Cache;
import org.ehcache.config.builders.CacheManagerBuilder;
import org.ehcache.config.builders.CacheConfigurationBuilder;
import org.ehcache.config.builders.ResourcePoolsBuilder;
import org.ehcache.config.builders.ExpiryPolicyBuilder;
import org.ehcache.config.CacheConfiguration;
import org.ehcache.config.ResourcePools;
import org.ehcache.expiry.ExpiryPolicy;
import org.ehcache.impl.internal.statistics.DefaultStatisticsService;
import org.ehcache.config.units.MemoryUnit;

import lucee.runtime.type.Struct;
import lucee.runtime.exp.PageException;

public class CbEhCacheService {

	private EhcacheManager _manager;

// CONSTRUCTOR
	public CbEhCacheService( String storageDirectory ) {
		_manager = (EhcacheManager)CacheManagerBuilder.newCacheManagerBuilder()
		                                              .using( new DefaultStatisticsService() )
		                                              .with( CacheManagerBuilder.persistence( new File( storageDirectory ) ) )
		                                              .build();

		_manager.init();
	}

// Public API
	public void close() {
		_manager.close();
	}

	public Cache createCache( String name, Struct cfmlConfig ) throws PageException, ClassNotFoundException {
		return _manager.createCache( name, _buildConfig( cfmlConfig ) );
	}

// Helpers
	private CacheConfiguration _buildConfig( Struct cfmlConfig ) throws PageException, ClassNotFoundException {
		Class keyClass   = _getClass( (String )cfmlConfig.get( "keyClass" ) );
		Class valueClass = _getClass( (String )cfmlConfig.get( "valueClass" ) );

		return CacheConfigurationBuilder.newCacheConfigurationBuilder( keyClass, valueClass, _getResourcePoolConfig( cfmlConfig ) )
		                                .withExpiry( _getExpiryPolicyConfig( cfmlConfig ) )
		                                .build();
	}

	private Class _getClass( String className ) throws ClassNotFoundException {
		switch( className ) {
			case "struct": return Class.forName( "lucee.runtime.type.Struct" );
			case "array" : return Class.forName( "lucee.runtime.type.Array"  );
			case "query" : return Class.forName( "lucee.runtime.type.Query"  );
		}

		return Class.forName( className );
	}


	private ResourcePools _getResourcePoolConfig( Struct cfmlConfig ) throws PageException {
		switch( (String )cfmlConfig.get( "storage" ) ) {
			case "offheap":
				return _configureOffHeapStorage( _toLong( cfmlConfig.get( "maxSizeInMb" ) ) );

			case "disk":
				return _configureDiskStorage( _toLong( cfmlConfig.get( "maxSizeInMb" ) ), _toBool( cfmlConfig.get( "persistent" ) ) );
		}

		// heap default
		return _configureHeapStorage( _toLong( cfmlConfig.get( "maxObjects" ) ), _toLong( cfmlConfig.get( "maxSizeInMb" ) ) );
	}

	private ResourcePools _configureHeapStorage( long maxObjects, long maxSizeInMb ) {
		if ( maxObjects > 0 ) {
			return ResourcePoolsBuilder.heap( maxObjects ).build();
		}

		return ResourcePoolsBuilder.newResourcePoolsBuilder().heap( maxSizeInMb, MemoryUnit.MB ).build();
	}

	private ResourcePools _configureOffHeapStorage( long maxSizeInMb ) {
		return ResourcePoolsBuilder.newResourcePoolsBuilder().offheap( maxSizeInMb, MemoryUnit.MB ).build();
	}

	private ResourcePools _configureDiskStorage( long maxSizeInMb, Boolean persistent ) {
		return ResourcePoolsBuilder.newResourcePoolsBuilder().disk( maxSizeInMb, MemoryUnit.MB, persistent ).build();
	}

	private ExpiryPolicy _getExpiryPolicyConfig( Struct cfmlConfig ) throws PageException  {
		long objectDefaultLastAccessTimeout = _toLong( cfmlConfig.get( "objectDefaultLastAccessTimeout" ) );
		long objectDefaultTimeout           = _toLong( cfmlConfig.get( "objectDefaultTimeout"           ) );

		if ( ( objectDefaultLastAccessTimeout + objectDefaultTimeout ) <= 0 ) {
			return ExpiryPolicyBuilder.noExpiration();
		}

		if ( _toBool( cfmlConfig.get( "useLastAccessTimeouts" ) ) ) {
			if ( objectDefaultLastAccessTimeout > 0 ) {
				return ExpiryPolicyBuilder.timeToIdleExpiration( Duration.ofMinutes( objectDefaultLastAccessTimeout ) );
			}
			return ExpiryPolicyBuilder.timeToIdleExpiration( Duration.ofMinutes( objectDefaultTimeout ) );
		}

		return ExpiryPolicyBuilder.timeToLiveExpiration( Duration.ofMinutes( objectDefaultTimeout ) );
	}

	private long _toLong( Object o ) {
		if (o instanceof Number) return ((Number) o).longValue();

		if (o instanceof CharSequence) {
			String str = o.toString();
			return Long.parseLong(str);
		}
		else if (o instanceof Character) return (((Character) o).charValue());

		return 0;
	}

	private Boolean _toBool( Object o ) {
		return ((Boolean) o).booleanValue();
	}

}
