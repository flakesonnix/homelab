package proto

import (
	"encoding/json"
	"testing"
)

func TestRequestRoundTrip(t *testing.T) {
	req := Request(42, "systemd", "restart", map[string]any{"unit": "microvm@cups"})
	data, err := json.Marshal(req)
	if err != nil {
		t.Fatalf("marshal: %v", err)
	}
	var got Envelope
	if err := json.Unmarshal(data, &got); err != nil {
		t.Fatalf("unmarshal: %v", err)
	}
	if got.ID != 42 || got.Type != TypeRequest || got.Plugin != "systemd" || got.Method != "restart" {
		t.Fatalf("unexpected envelope: %+v", got)
	}
	params, ok := got.Params.(map[string]any)
	if !ok || params["unit"] != "microvm@cups" {
		t.Fatalf("unexpected params: %+v", got.Params)
	}
}

func TestErrorEnvelope(t *testing.T) {
	e := ErrorEnvelope(7, "NOT_FOUND", "no such unit")
	data, err := json.Marshal(e)
	if err != nil {
		t.Fatalf("marshal: %v", err)
	}
	var got Envelope
	if err := json.Unmarshal(data, &got); err != nil {
		t.Fatalf("unmarshal: %v", err)
	}
	if got.Error == nil || got.Error.Code != "NOT_FOUND" {
		t.Fatalf("unexpected error: %+v", got.Error)
	}
}

func TestEventEnvelope(t *testing.T) {
	e := Event(9, "journal:mireo", map[string]any{"ts": 1})
	data, err := json.Marshal(e)
	if err != nil {
		t.Fatalf("marshal: %v", err)
	}
	var got Envelope
	if err := json.Unmarshal(data, &got); err != nil {
		t.Fatalf("unmarshal: %v", err)
	}
	if got.Type != TypeEvent || got.Stream != "journal:mireo" {
		t.Fatalf("unexpected envelope: %+v", got)
	}
}
