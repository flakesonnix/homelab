// Command homectl is the homectl CLI (M0: status against the API).
package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"log"
	"net/http"
	"os"
	"time"

	"homectl/shared/version"
)

func main() {
	api := flag.String("api", "http://localhost:8443", "homectl API base URL")
	showVersion := flag.Bool("version", false, "print version and exit")
	flag.Parse()

	if *showVersion {
		log.Println(version.String())
		return
	}

	cmd := flag.Arg(0)
	switch cmd {
	case "", "status":
		if err := status(*api); err != nil {
			log.Fatal(err)
		}
	case "health":
		if err := health(*api); err != nil {
			log.Fatal(err)
		}
	default:
		fmt.Fprintf(os.Stderr, "usage: homectl [status|health] [--api URL]\n")
		os.Exit(2)
	}
}

func health(api string) error {
	resp, err := http.Get(api + "/api/v1/health")
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	var body map[string]any
	if err := json.NewDecoder(resp.Body).Decode(&body); err != nil {
		return err
	}
	ok, _ := body["ok"].(bool)
	if !ok {
		return fmt.Errorf("API unhealthy")
	}
	fmt.Printf("API %v @ %s\n", body["version"], api)
	return nil
}

func status(api string) error {
	client := &http.Client{Timeout: 5 * time.Second}
	resp, err := client.Get(api + "/api/v1/meta")
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	var meta map[string]any
	if err := json.NewDecoder(resp.Body).Decode(&meta); err != nil {
		return err
	}
	manifest, ok := meta["manifest"].(map[string]any)
	if !ok {
		return fmt.Errorf("no manifest in meta response")
	}
	hosts, _ := manifest["hosts"].(map[string]any)
	fmt.Printf("homectl: %d hosts in manifest\n", len(hosts))
	return nil
}
