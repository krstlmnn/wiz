implement Wiz;

include "sys.m";
	sys: Sys;
include "draw.m";
include "arg.m";
	arg: Arg;
include "bufio.m";
	bufio: Bufio;
	Iobuf: import bufio;
include "dial.m";
	dial: Dial;
include "json.m";
	json: JSON;
	JValue: import json;

Wiz: module {
	init: fn(nil: ref Draw->Context, args: list of string);
};

PORT: con "38899";

callbulb(addr: string): ref bufio->Iobuf {
	c := dial->dial(dial->netmkaddr(addr, "udp", PORT), nil);
	if(c == nil)
		return nil;
	return bufio->fopen(c.dfd, bufio->ORDWR);
}

scenetoid(s: string): int {
	scenes := array[] of {
		"ocean",
		"romance",
		"sunset",
		"party",
		"fireplace",
		"cozy",
		"forest",
		"pastel colors",
		"wake up",
		"bedtime",
		"warm white",
		"daylight",
		"cool white",
		"night light",
		"focus",
		"relax",
		"true colors",
		"tv time",
		"plant growth",
		"spring",
		"summer",
		"fall",
		"deep dive",
		"jungle",
		"mojito",
		"club",
		"christmas",
		"halloween",
		"candlelight",
		"golden white",
		"pulse",
		"steampunk",
		"divali"
	};

	for(i := 0; i < len scenes; i++) {
		if(s == scenes[i])
			return ++i;
	}

	return -1;
}

init(nil: ref Draw->Context, args: list of string) {
	sys = load Sys Sys->PATH;
	arg = load Arg Arg->PATH;
	bufio = load Bufio Bufio->PATH;
	dial = load Dial Dial->PATH;
	json = load JSON JSON->PATH;

	stderr := sys->fildes(2);

	arg->init(args);
	arg->setusage("wiz [ -d dim ] [ -s speed ] [ -c r g b ] | [ -S scene ] | [ -w kelvin ] addr");

	json->init(bufio);
	params := json->jvobject(nil);
	req := json->jvobject(nil);
	req.set("method", json->jvstring("setPilot"));
	req.set("params", params);

	while((c := arg->opt()) != 0) {
		case c {
		'c' =>
			params.set("r", json->jvint(int arg->earg()));
			params.set("g", json->jvint(int arg->earg()));
			params.set("b", json->jvint(int arg->earg()));
		'd' =>
			params.set("dimming", json->jvint(int arg->earg()));
		's' =>
			params.set("speed", json->jvint(int arg->earg()));
		'S' =>
			params.set("sceneId", json->jvint(scenetoid(arg->earg())));
		'w' =>
			params.set("temp", json->jvint(int arg->earg()));
		* =>
			arg->usage();
		}
	}

	args = arg->argv();
	if(len args != 1)
		arg->usage();

	bulb := callbulb(hd args);
	if(bulb == nil) {
		sys->fprint(stderr, "wiz: can't call bulb: %r\n");
		raise "fail:callbulb";
	}

	if(json->writejson(bulb, req) < 0) {
		sys->fprint(stderr, "wiz: can't write to bulb: %r\n");
		raise "fail:writejson";
	}

	(resp, err) := json->readjson(bulb);
	if(err != nil) {
		sys->fprint(stderr, "wiz: can't read from bulb: %r\n");
		raise "fail:readjson";
	}

	error := resp.get("error");
	if(error != nil) {
		pick msg := error.get("message") {
		String =>
			sys->fprint(stderr, "wiz: jsonrpc: %s\n", msg.s);
		* =>
			sys->fprint(stderr, "wiz: invalid response format\n");
		}
		raise "fail:jsonrpc";
	}
	

	bulb.close();
}