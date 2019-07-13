/**
 * Handler for receiving cache events from the cluster
 *
 *
 */
component {

	private void function set( event, rc, prc, cacheName="", objectKey="", object="" ) {
		var cache = getModel( dsl="cachebox:#arguments.cacheName#" );

		cache.set(
			  propagate = false
			, objectKey = arguments.objectKey
			, object    = arguments.object
		);

	}

	private void function clearall( event, rc, prc, cacheName="" ) {
		var cache = getModel( dsl="cachebox:#arguments.cacheName#" );

		cache.clearall( propagate=false );
	}

	private void function clear( event, rc, prc, cacheName="", objectKey="" ) {
		var cache = getModel( dsl="cachebox:#arguments.cacheName#" );

		cache.clear(
			  propagate = false
			, objectKey = arguments.objectKey
		);
	}

}