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
	./update-docs

check: compile dialyzer xref

test: proper
	ERL_FLAGS="-config config/test.sys.config" ./rebar3 eunit --module=valvex_tests

proper:
	ERL_FLAGS="-config config/sys.config" ./rebar3 eunit --module=valvex_tests_proper
