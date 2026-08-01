// Package version holds the homectl build version.
package version

// Version is the semantic version of homectl.
const Version = "0.1.0"

// String returns the full version string.
func String() string {
	return "homectl " + Version
}
