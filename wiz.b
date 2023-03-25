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

init(nil: ref Draw->Context, args: list of string) {
	sys = load Sys Sys->PATH;
	arg = load Arg Arg->PATH;
	bufio = load Bufio Bufio->PATH;
	dial = load Dial Dial->PATH;
	json = load JSON JSON->PATH;

	stderr := sys->fildes(2);

	arg->init(args);
	arg->setusage("wiz [ -d dim ] [ -w kelvin ] addr");

	json->init(bufio);
	params := json->jvobject(nil);
	req := json->jvobject(nil);
	req.set("method", json->jvstring("setPilot"));
	req.set("params", params);

	while((c := arg->opt()) != 0) {
		case c {
		'd' =>
			params.set("dimming", json->jvint(int arg->earg()));
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