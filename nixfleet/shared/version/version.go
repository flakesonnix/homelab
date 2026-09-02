// Package version holds the nixfleet build version.
package version

// Version is the semantic version of nixfleet.
const Version = "0.1.0"

// String returns the full version string.
func String() string {
	return "nixfleet " + Version
}
