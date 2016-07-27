import vibe.d;
import models.manager, models.picture, models.user;
import imaged.image;
import std.file, std.path;

shared static this()
{
	auto booru = new Booru;
	auto settings = new HTTPServerSettings;
	settings.port = 8080;
	settings.bindAddresses = ["::1", "127.0.0.1"];
	auto router = new URLRouter;
	//router.registerWebInterface(new Booru);
	router.get("*", serveStaticFiles("public/"));
	router.any("*", &Booru.ensureAuth);
	router.registerWebInterface(booru);
	listenHTTP(settings, router);
	logInfo("Please open http://127.0.0.1:8080/ in your browser.");
}

class URLRules
{
	string[string] rules;

	void register(URLRouter router)
	{
		/*foreach(code, url; rules) {
			router.get(url, code); //TODO: wrong
		}*/
	}
};


final class Booru
{
	Manager!Picture pics;
	Manager!User users; 
	string[string] url;
	Booru booru;
	Path mediaPath = "media/";
	Path fullImagePath = "media/pictures/full/";
	Path thumbnailImagePath = "media/pictures/thumbnail/";

	this()
	{
		pics = new Manager!(Picture);
		booru = this;
		url["index"] = "/";
		url["add_picture"] = "add_picture";
		url["posts"] = "posts";
		url["about"] = "about";
		url["login"] = "login";
		url["logout"] = "logout";
		url["register"] = "register";
		url["user_profile"] = "user_profile";
	}

	void index(int page = 1)
	{
		//writeln(request.queryString);

		render!("booru/index.dt", booru);
	}

	void getPost(int _postid)
	{
		Picture picture = pics.get(_postid);
		render!("booru/picture.dt", booru, picture);
	}

	void getAbout()
	{
		render!("booru/about.dt", booru);
	}

	void getAddPicture()
	{
		render!("booru/add_picture.dt", booru);
	}

	void postAddPicture(HTTPServerRequest req, scope HTTPServerResponse res)
	{
		Picture picture;
		picture.id = pics.getCount();
		picture.name = req.form["name"];
		picture.src = req.form["src"];
		picture.rating = req.form["rating"][0];
		picture.tags = req.form["tags"].split();

		auto pf = "file" in req.files;
		//enforce(pf !is null, "No file uploaded!");
		string filename = to!string(picture.id)~extension(pf.filename.toString());
		Path filepath = fullImagePath ~ filename;
		picture.file_url = filepath.toNativeString();
		try moveFile(pf.tempPath, filepath);
		catch (Exception e) {
			logWarn("Failed to move file to destination folder: %s", e.msg);
			logInfo("Performing copy+delete instead.");
			copyFile(pf.tempPath, filepath);
		}

		picture.thumbnail_url = thumbnailImagePath.toNativeString() ~ filename;
		IMGError err;
		Image orig_img = load(picture.file_url, err);
		auto img = orig_img.copy();
		img.resize(150,150, Image.ResizeAlgo.NEAREST);
		img.write(filename);

		pics.add(picture);
		redirect("/add_picture");
	}

	void login(HTTPServerRequest req, HTTPServerResponse res)
	{
		if (req.method != HTTPMethod.POST &&
			req.method != HTTPMethod.GET) return;
		auto formdata = (req.method == HTTPMethod.POST) ? &req.form : &req.query;
		string username = formdata.get("username");
		string password = formdata.get("password");
		if ( users.have(["username":username, "password":password]) )
		{
			if (!req.session)
				req.session = res.startSession();
			User user;
			user.loggedIn = true;
			user.nickname = username;
			req.session.set!User("user", user);
			res.redirect("/");
		}
		res.redirect("/");
	}

	void logout(HTTPServerRequest req,
		HTTPServerResponse res)
	{
		req.session.set!User("user", User.init);
		res.terminateSession();
		res.redirect("/");
	}

	static void ensureAuth(HTTPServerRequest req,
		HTTPServerResponse res)
	{
		if (req.session)
		{
			auto user = req.session.get!User("user");
			if (user.loggedIn) return ;
		}
		res.redirect("/");
	}

};


