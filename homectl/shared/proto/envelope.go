// Package proto defines the JSON envelope exchanged between API and agent
// over the WebSocket transport. All payloads are structured JSON; no shell
// strings ever cross the wire.
package proto

// Type discriminates envelope kinds.
type Type string

const (
	// TypeRequest is a client -> agent call.
	TypeRequest Type = "request"
	// TypeResponse is the answer to a request.
	TypeResponse Type = "response"
	// TypeError is a failed request.
	TypeError Type = "error"
	// TypeEvent is a chunk of a streaming response.
	TypeEvent Type = "event"
)

// Envelope is a single protocol message.
type Envelope struct {
	ID      int64  `json:"id"`
	Type    Type   `json:"type"`
	Stream  string `json:"stream,omitempty"`
	Plugin  string `json:"plugin,omitempty"`
	Method  string `json:"method,omitempty"`
	Params  any    `json:"params,omitempty"`
	Result  any    `json:"result,omitempty"`
	Error   *Error `json:"error,omitempty"`
	Event   any    `json:"event,omitempty"`
	TTLMS   int    `json:"ttl_ms,omitempty"`
	Version string `json:"version,omitempty"`
}

// Error is a structured protocol error.
type Error struct {
	Code    string `json:"code"`
	Message string `json:"message"`
}

// Request creates a one-shot request envelope.
func Request(id int64, plugin, method string, params any) Envelope {
	return Envelope{ID: id, Type: TypeRequest, Plugin: plugin, Method: method, Params: params}
}

// Response creates a response envelope.
func Response(id int64, result any) Envelope {
	return Envelope{ID: id, Type: TypeResponse, Result: result}
}

// ErrorEnvelope creates an error envelope.
func ErrorEnvelope(id int64, code, message string) Envelope {
	return Envelope{ID: id, Type: TypeError, Error: &Error{Code: code, Message: message}}
}

// Event creates a stream event envelope.
func Event(id int64, stream string, chunk any) Envelope {
	return Envelope{ID: id, Type: TypeEvent, Stream: stream, Event: chunk}
}
