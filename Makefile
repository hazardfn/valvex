.PHONY: all compile test

all: compile rel

compile:
	./rebar3 compile
dialyzer:
	./rebar3 dialyzer
rel:
	./rebar3 release
xref:
	./rebar3 xref
docs:
	./rebar3 edoc

check: compile dialyzer xref

test:
	ERL_FLAGS="-config config/test.sys.config" ./rebar3 eunit
