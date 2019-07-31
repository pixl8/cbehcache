# Changelog

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
