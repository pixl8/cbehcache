component implements="coldbox.system.cache.util.ICacheStats" {

	public any function init( required any statsService ) {
		_setStatsService( arguments.statsService );

		return this;
	}

	public struct function getMemento() {
		return {
			  lastReapDateTime   = ""
			, hits               = getHits()
			, misses             = getMisses()
			, evictionCount      = getEvictionCount()
			, garbageCollections = 0
		};
	}

	numeric function getCachePerformanceRatio() {
		return _getStatsService().getCacheHitPercentage();
	}

	numeric function getObjectCount() {
		var allStats = _getStatsService().getKnownStatistics();
		var statKeys = StructKeyArray( allStats );
		var total    = 0;

		for( var key in statKeys ) {
			if ( ReFindNoCase( ":MappingCount$", key ) ) {
				total += Val( allStats[ key ].value() );
			}
		}

		return total;
	}

	numeric function getGarbageCollections() {
		return 0;
	}
	numeric function getEvictionCount() {
		return _getStatsService().getCacheEvictions();
	}
	numeric function getHits() {
		return _getStatsService().getCacheHits();
	}
	numeric function getMisses(){
		return _getStatsService().getCacheMisses();
	}
	function getLastReapDatetime() {
		return "";
	}

	function clearStatistics() {
		_getStatsService().clear();
	}

// getters and setters
	private any function _getStatsService() {
	    return _statsService;
	}
	private void function _setStatsService( required any statsService ) {
	    _statsService = arguments.statsService;
	}
}