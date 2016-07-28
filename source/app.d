import vibe.d;
import models.manager, models.picture, models.user;
import std.file, std.path;
import derelict.freeimage.freeimage;

shared static this()
{
	DerelictFI.load();
	auto booru = new Booru;
	auto settings = new HTTPServerSettings;
	settings.port = 8080;
	settings.bindAddresses = ["::1", "127.0.0.1"];
	settings.sessionStore = new MemorySessionStore;
	auto router = new URLRouter;
	router.get("*", serveStaticFiles("public/"));
	//settings.errorPageHandler = toDelegate(&booru.errorPage);
	router.registerWebInterface(booru);
	listenHTTP(settings, router);
	logInfo("Please open http://127.0.0.1:8080/ in your browser.");
}

final class Booru
{

	Manager!Picture pics;
	Manager!User users; 
	Booru booru;
	Path mediaPath = "public/media/";
	Path fullImagePath = "public/media/pictures/full/";
	Path thumbnailImagePath = "public/media/pictures/thumbnail/";
	Path previewImagePath = "public/media/pictures/preview/";
	SessionVar!(User, "user") m_user;

	const int thumbnail_size = 150;
	const int preview_size = 1000;


	this()
	{
		pics = new Manager!(Picture);
		users = new Manager!(User);
		booru = this;
	}

	void index(int page = 1)
	{
		//writeln(request.queryString);

		render!("booru/index.dt", booru);
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
		picture.id = pics.getValue();
		pics.increment();
		picture.name = req.form["name"];
		picture.src = req.form["src"];
		picture.rating = req.form["rating"][0];
		picture.tags = req.form["tags"].split();
		picture.uploaded_by = m_user.nickname;

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
		picture.preview_url = previewImagePath.toNativeString() ~ filename;

		FREE_IMAGE_FORMAT fmt = FreeImage_GetFileType(toStringz(picture.file_url), 0);
		FIBITMAP* bmp = FreeImage_Load(fmt, toStringz(picture.file_url), 0);
		// Thumbnail.
		FIBITMAP* thumb = FreeImage_MakeThumbnail(bmp, thumbnail_size, true);
		FreeImage_Save(FIF_JPEG, thumb, toStringz(picture.thumbnail_url), 0);
		// Preview.
		FIBITMAP* preview = FreeImage_MakeThumbnail(bmp, preview_size, true);
		FreeImage_Save(FIF_JPEG, preview, toStringz(picture.preview_url), 0);

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
			//req.session.set!User("user", user);
			m_user = user;
			res.redirect("/");
		}
		res.redirect("/");
	}

	void postLogout(HTTPServerRequest req, HTTPServerResponse res)
	{
		req.session.set!User("user", User.init);
		res.terminateSession();
		res.redirect("/");
	}

	private enum auth = before!ensureAuth("authUser");

	private string ensureAuth(HTTPServerRequest req, HTTPServerResponse res)
	{
		if (!m_user.loggedIn)
			res.redirect("login");
		return m_user.nickname;
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

	void errorPage(HTTPServerRequest req, HTTPServerResponse res, HTTPServerErrorInfo error)
	{
		render!("error.dt", booru, error);
	}

	mixin PrivateAccessProxy;

};


