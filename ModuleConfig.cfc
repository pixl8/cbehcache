component {

	// Module Properties
	this.title 				= "EH Cache Caching System for Coldbox";
	this.author 			= "Pixl8 Group";
	this.description 		= "A wrapper and abstraction to use EHCache directly with Cachebox";
	this.entryPoint			= "cbehcache";
	this.cfMapping			= "cbehcache";

	function configure(){
	}

	function applicationEnd( ){
		if ( StructKeyExists( application, "ehCacheManager" ) ) {
			lock type="exclusive" name="ehCacheManagerShutdown" timeout=5 {
				if ( StructKeyExists( application, "ehCacheManager" ) ) {
					try {
						SystemOutput( "Attempting safe shutdown of EHCache manager..." );
						application.ehCacheManager.close();
						SystemOutput( "Safe shutdown of EHCache manager complete." );
					} catch( any e ) {
						SystemOutput( "Error closing the EHCache cache manager: #( e.message ?: '' )#. Detail: #( e.detail ?: '' )#" );
					}
				}
			}
		}
	}

	function onApplicationEnd() {
		applicationEnd(); // alias for Preside applications
	}

}
