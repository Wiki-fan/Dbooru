module app;
import vibe.d;
import derelict.freeimage.freeimage;
import booru.booru;

shared static this()
{
	DerelictFI.load();
	auto router = new URLRouter;

	auto booru = new Booru;
	auto settings = new HTTPServerSettings;
	settings.registerBooruSettings(booru.settings);
	router.get("*", serveStaticFiles("public/"));
	//settings.errorPageHandler = toDelegate(&errorPage);
	router.registerWebInterface(booru);
	listenHTTP(settings, router);
	logInfo("Please open http://127.0.0.1:8080/ in your browser.");
}

