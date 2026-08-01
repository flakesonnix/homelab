// Command homectl-agent runs on every managed host (M0: identity + version
// only; the WebSocket connection and plugins arrive in M1).
package main

import (
	"flag"
	"log"

	"homectl/shared/version"
)

func main() {
	host := flag.String("host", osHostname(), "hostname reported to the API")
	showVersion := flag.Bool("version", false, "print version and exit")
	flag.Parse()

	if *showVersion {
		log.Println(version.String())
		return
	}
	log.Printf("%s starting agent for host %s", version.String(), *host)
}
