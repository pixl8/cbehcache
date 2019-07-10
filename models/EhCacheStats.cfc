component implements="coldbox.system.cache.util.ICacheStats" {

	public any function init( required any ehProvider ) {
		_setEhCacheProvider( arguments.ehProvider );

		return this;
	}

	public struct function getMemento() {
		return {
			  lastReapDateTime   = ""
			, hits               = 0
			, misses             = 0
			, evictionCount      = 0
			, garbageCollections = 0
		};
	}

	numeric function getCachePerformanceRatio() {
		var hits   = getHits();
		var misses = getMisses();
		var total  = hits + misses;

		return total ? ( ( hits / total ) * 100 ) : 0;
	}

	numeric function getObjectCount() {
		return _getEhCacheProvider().getSize();
	}

	numeric function getGarbageCollections() {
		return 0;
	}
	numeric function getEvictionCount() {
		return 0;
	}
	numeric function getHits() {
		return 0;
	}
	numeric function getMisses(){
		return 0;
	}
	function getLastReapDatetime() {
		return "";
	}

	function clearStatistics() {
		// not implemented
	}

// getters and setters
	private any function _getEhCacheProvider() {
	    return _jcsProvider;
	}
	private void function _setEhCacheProvider( required any jcsProvider ) {
	    _jcsProvider = arguments.jcsProvider;
	}
}