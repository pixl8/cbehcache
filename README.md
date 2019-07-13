# EHCache Cachebox Provider with JGroups clustering

This module makes EHCache 3.7 available as a Cachebox provider, with clustering support using [jGroups](https://github.com/pixl8/cbjgroups). The project supports the following features:

* Configuration of heap, offheap or disk storage
* Configuration of cache timeouts
* Configuration of resource limits
* Configuration of a jGroups cluster to replicate caches

No tiered resources or _Terracota clustering_ are currently available. These could come in a later resource pending demand.

## Get involved

Contribution is very welcome. You can get involved by:

* Raising issues in [Github](https://github.com/pixl8/cbehcache), both ideas and bugs welcome
* Creating pull requests in [Github](https://github.com/pixl8/cbehcache)

Or search out the authors for anything else. You can generally find us on Preside slack: [https://presidecms-slack.herokuapp.com/](https://presidecms-slack.herokuapp.com/).

## Configuration

Caches are configured in your Cachebox.cfc as per the Cachebox documentation. The following example shows all the _default_ settings:

```cfc
caches.mycache = {
      provider   = "cbehcache.models.EhCacheProvider"
    , properties = {
		  storage                        = "heap"
		, persistent                     = false
		, objectDefaultTimeout           = 60
		, objectDefaultLastAccessTimeout = 0
		, useLastAccessTimeouts          = false
		, maxObjects                     = 1000
		, maxSizeInMb                    = 0
		, keyClass                       = "java.lang.String"
		, valueClass                     = "java.lang.Object"
		, cluster                        = false
		, clusterName                    = "cbehcache"
		, propagateDeletes               = true
		, propagatePuts                  = false
	}
}
```

### Configuration notes

#### Storage

Can be either `heap` (default), `nonheap` or `disk`. The `persistent` setting applies only to `disk` storage. Setting to `true` will mean that a restart of the application will not reset the cache in disk if it already exists.

_**Note:** Nonheap is a special memory based cache that does not require GC so can save overhead. It will, however, incur serialization and deserialization overhead and is advised to be used only for **very** large caches._

#### Timeouts

The cache can use **either** time to live (TTL) **or** time to idle (TTI) timeouts. These modes correspond to `objectDefaultTimeout` (TTL) and `objectDefaultLastAccessTimeout` (TTI). To use TTI, ensure that `useLastAccessTimeouts` is set to `true`. 

Set a value of `0` to have no timeouts.

_**Note:** The semantics here have been chosen to keep as close to the default Coldbox cachebox provider properties as possible._

#### Resource limits

The `maxObjects` and `maxSizeInMb` properties define the resource limits for your cache. For `heap` storage, you can define **either** one (not both). A value of `zero` will mean no limit. 

For `nonheap` and `disk` storage, only `maxSizeInMb` is possible.

#### Key and Value classes

For serialization of caches (`nonheap` and `disk` storages), the cache requires that you define the class used for both keys and values in the cache. If you know that you will always be storing _strings_ in the cache, set the `valueClass` to `java.lang.String`.

#### Clustering

The minimal configuration required is to set `clustering=true` to enable clustering. This will:

* propagate cache deletes across the system 
* setup a cluster named `cbehcache` with the default `jgroups` cluster settings of automatically detecting peers using UDP multicast discovery

See the [cbjgroups](https://github.com/pixl8/cbjgroups) project documentation for full cluster configuration details. You can either configure a `cbehcache` cluster, or provide your own cluster IDs with their own configuration.

Set `propagatePuts` to `true` to have any additions to the cache on any node to be replicated across all nodes (default is `false`).



