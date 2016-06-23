.PHONY: all compile test

all: compile

compile:
	./rebar3 compile

test:
	ERL_FLAGS="-config config/test.sys.config" ./rebar3 eunit
