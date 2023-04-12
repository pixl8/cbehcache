# Changelog

## v1.2.13

* Fix [#14](https://github.com/pixl8/cbehcache/issues/14) - More liberal error catching to make more robust cache system

## v1.2.12

* Fix [#13](https://github.com/pixl8/cbehcache/issues/13) - Catch correct exception for already existing cache under race conditions

## v1.2.11

* Fix [#11](https://github.com/pixl8/cbehcache/issues/11) - issue with cache creation race conditions throwing errors

## v1.2.10

Migrate to github actions

## v1.2.9

* Upgrade cbjgroups with fix for memory leak in kubernetes

## v1.2.8

* Upgrade cbjgroups with fix for running cfml in app context on cluster membership change events

## v1.2.7

* Add config option to allow all object keys to be forced to lower-case

## v1.2.6

* Upgrade to cbjgroups 0.3.0

## v1.2.5

* Upgrade to cbjgroups 0.2.4 to fix issue with 0.2.3

## v1.2.4

* Remove debug output

## v1.2.3

* Update to cbjgroups 0.2.3 to fix issue with limitation on size of cache objects that can be sent to other cluster nodes

## v1.2.2

* Adding working logic for cache.getKeys() method. Thanks to Florindo Lopez.

## v1.2.1

* Update cbjgroups dependency version

## v1.2.0

* Update dependency on cbjgroups to add k8s support

## v1.1.6

* [#6](https://github.com/pixl8/cbehcache/issues/6) Fix issue with cbehcache mapping not always being available for path resolution

## v1.1.5

* [#4](https://github.com/pixl8/cbehcache/issues/4) Add some debugging to illegalstate exceptions when registering caches

## v1.1.4

* [#2](https://github.com/pixl8/cbehcache/issues/2) Allow the use of CFML struct, query and array types for the 'ValueClass' for non-heap storage.

## v1.1.3

* [#1](https://github.com/pixl8/cbehcache/issues/1) Improve performance of cluster cache operations that potentially fail when the cache does not (yet) exist in the listening cluster node. Ignore missing caches and do not go to wirebox each time to fetch the cache.

## v1.1.2

* Fix for clear by key snippet not being possible (just have to clear all for now!)

## v1.1.1

* Fix for hardcoded path accidentally left in while local testing

## v1.1.0

* Added support for clustering using jGroups ([cbjgroups](https://github.com/pixl8/cbjgroups))

## v1.0.1

* Added support for `nonheap` and `disk` storage
* Added support for both `TTL` _and_ `TTI` expiry models
* Added working statistics
* Added documentation in README

## v0.1.1

* Build fixes

## v0.1.0

Initial proof of concept with with:

* Only Heapspace resource configurable
* Working with existing Coldbox cachebox provider config
* Timeouts not settable per individual entry
* No statistics
