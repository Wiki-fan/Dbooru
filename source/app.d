module app;
import std.datetime;
import vibe.d;
import models.manager, models.picture, models.user, models.tag;
import std.file, std.path, std.stdio;
import derelict.freeimage.freeimage;
import settings;

shared static this()
{
	DerelictFI.load();
	auto booru = new Booru;
	auto settings = new HTTPServerSettings;
	/*settings.port = 8080;
	settings.bindAddresses = ["::1", "127.0.0.1"];
	settings.sessionStore = new MemorySessionStore;*/
	settings.registerBooruSettings(booru.settings);
	auto router = new URLRouter;
	router.get("*", serveStaticFiles("public/"));
	//settings.errorPageHandler = toDelegate(&errorPage);
	router.registerWebInterface(booru);
	listenHTTP(settings, router);
	logInfo("Please open http://127.0.0.1:8080/ in your browser.");
}

void registerBooruSettings(HTTPServerSettings settings, BooruSettings booruSettings)
{
	settings.bindAddresses = [booruSettings.siteURL.host];
	settings.port = booruSettings.siteURL.port;
	settings.sessionStore = new MemorySessionStore;
}

// Custom implementation of tag query string. Standard delimeter in query is ',', can import strings using any delimiter character.
struct TagString
{
	this(string tags, string delim)
	{
		foreach(tag; tags.split(delim))
			this.tags[tag] = true;
	}

	string toQueryString(string delim = ",")
	{
		return ("%-(%s"~delim~"%)").format(tags.keys);
	}

	void add(string tag)
	{
		tags[tag] = true;
	}

	void remove(string tag)
	{
		tags.remove(tag);
	}

private:
	bool[string] tags;
}

final class Booru
{
	Manager!(Picture) pics;
	Manager!User users;
	Manager!Tag tags;
	BooruSettings settings;
	Booru booru; // Has value of 'this'.
	SessionVar!(User, "user") m_user;

	this()
	{
		pics = new Manager!(Picture);
		users = new Manager!(User);
		tags = new Manager!Tag;
		settings = new BooruSettings;
		booru = this;
	}

	@method(HTTPMethod.GET)
	void index(HTTPServerRequest req, scope HTTPServerResponse res, int page = 1)
	{
		//writeln(request.queryString);
		string* tags = ("tags" in req.query);
		Picture[] pictures;
		if (tags is null || *tags == "") {
			//logInfo(serializeToBson(["id":["$gte":(page-1)*settings.postsOnPage, "$lt":page*settings.postsOnPage]]).toString());
			pictures = pics.getAll(serializeToBson(["id":["$gte":(page-1)*settings.postsOnPage, "$lt":page*settings.postsOnPage]]));
		} else {
			//logInfo(bson.toString());
			pictures = pics.getAll( serializeToBson(["tags":["$all":(*tags).split(',')]]) );
		}
		render!("booru/index.dt", booru, pictures);
	}

	@method(HTTPMethod.POST)
	void index(HTTPServerRequest req, scope HTTPServerResponse res, string tags)
	{
		TagString tag_string = TagString(tags, " ");
		req.query["tags"] = tag_string.toQueryString();
		redirect("/?"~req.query.urlEncode);
	}

	@path("/posts/:postid/")
	void getPosts(int _postid)
	{
		Picture picture = pics.get(_postid);
		render!("booru/picture.dt", booru, picture);
	}

	void getAbout()
	{
		render!("booru/about.dt", booru);
	}

	@auth
	void getAddPicture(string authUser)
	{
		render!("booru/add_picture.dt", booru);
	}

	@auth
	void postAddPicture(HTTPServerRequest req, scope HTTPServerResponse res, string authUser)
	{
		Picture picture;
		picture.id = pics.getNextIndex();
		picture.name = req.form["name"];
		picture.src = req.form["src"];
		picture.rating = req.form["rating"][0];
		picture.tags = req.form["tags"].split();
		foreach(tagName; picture.tags) {
			if (!tags.have(["name":tagName]))
				tags.add(Tag(tagName, 0));
		}
		picture.uploaded_by = m_user.nickname;
		picture.upload_datetime = cast(DateTime)Clock.currTime();

		auto pf = "file" in req.files;
		//enforce(pf !is null, "No file uploaded!");
		string filename = to!string(picture.id)~extension(pf.filename.toString());

		// File urls. Get real system path appending settings.publicPath at left.
		picture.file_url = (settings.fullImagePath~filename).toNativeString();
		picture.thumbnail_url = (settings.thumbnailImagePath~filename).toNativeString();
		picture.preview_url = (settings.previewImagePath~filename).toNativeString();

		string origFileName = (settings.publicPath~picture.file_url).toNativeString();
		// Moving file from temporary folder to media storage.
		try moveFile(pf.tempPath.toNativeString(), origFileName);
		catch (Exception e) {
			logWarn("Failed to move file to destination folder: %s", e.msg);
			logInfo("Performing copy+delete instead.");
			copyFile(pf.tempPath.toNativeString(), origFileName);
		}

		// File size.
		File f = File(origFileName, "r");
		picture.file_size = f.size;
		f.close();

		FREE_IMAGE_FORMAT fmt = FreeImage_GetFileType(toStringz(origFileName), 0);
		FIBITMAP* bmp = FreeImage_Load(fmt, toStringz(origFileName), 0);
		// Sizes.
		picture.image_width = FreeImage_GetWidth(bmp);
		picture.image_height = FreeImage_GetHeight(bmp);
		// Thumbnail.
		FIBITMAP* thumb = FreeImage_MakeThumbnail(bmp, settings.thumbnail_size, true);
		FreeImage_Save(FIF_JPEG, thumb, toStringz((settings.publicPath~picture.thumbnail_url).toNativeString()), 0);
		// Preview.
		FIBITMAP* preview = FreeImage_MakeThumbnail(bmp, settings.preview_size, true);
		FreeImage_Save(FIF_JPEG, preview, toStringz((settings.publicPath~picture.preview_url).toNativeString()), 0);
		
		FreeImage_Unload(bmp);
		FreeImage_Unload(thumb);
		FreeImage_Unload(preview);

		pics.add(picture);
		redirect("/add_picture");
	}

	void getLogin()
	{
		render!("log_in/login.dt", booru);
	}

	void postLogin(HTTPServerRequest req, HTTPServerResponse res)
	{
		string username = req.form["nickname"];
		string password = req.form["password"];
		if ( users.have(["nickname":username, "password":password]) )
		{
			if (!req.session)
				req.session = res.startSession();
			User user;
			user.loggedIn = true;
			user.nickname = username;
			//req.session.set!User("user", user); TODO: what is this?
			m_user = user;
			res.redirect("/");
		}
		res.redirect("/");
	}

	void getLogout(HTTPServerRequest req, HTTPServerResponse res)
	{
		req.session.set!User("user", User.init);
		res.terminateSession();
		res.redirect("/");
	}

	void getRegister()
	{
		render!("log_in/register.dt", booru);
	}

	void postRegister(HTTPServerRequest req, HTTPServerResponse res)
	{
		User usr;
		// TODO: check correctness and uniqueness.
		usr.name = req.form.get("name");
		usr.nickname = req.form.get("nickname");
		usr.password = req.form.get("password");
		usr.registration_datetime = cast(DateTime)Clock.currTime();

		users.add(usr);

		res.redirect("/login");
	}

	@path("/user_profile/:nickname/")
	void getUserProfile(HTTPServerRequest req, HTTPServerResponse res, string _nickname)
	{
		User user = users.get(["nickname":_nickname]);
		render!("log_in/user_profile.dt", booru, user);
	}

	void getUserList(HTTPServerRequest req, HTTPServerResponse res)
	{
		render!("log_in/user_list.dt", booru);
	}

	/*void errorPage(HTTPServerRequest req, HTTPServerResponse res, HTTPServerErrorInfo error)
	{
		render!("error.dt", req, error)(res);
	}*/

	mixin PrivateAccessProxy;

private:
	enum auth = before!ensureAuth("authUser");
	
	string ensureAuth(HTTPServerRequest req, HTTPServerResponse res)
	{
		if (!m_user.loggedIn)
			res.redirect("login");
		return m_user.nickname;
	}

	Bson formBsonQuery(T)(T dict)
	{
		return serializeToBson(dict);
	}
};
