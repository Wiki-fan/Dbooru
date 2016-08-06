module booru.settings;

import vibe.d;

class BooruSettings
{
	// Picture sizes.
	const int thumbnail_size = 150;
	const int preview_size = 1000;
	const int avatar_size = 300;
	// Database parameters.
	string databaseURL = "mongodb://localhost/";
	string databaseName = "Dbooru";
	// 
	string configName = "global";
	// Booru information.
	string booruName = "Dbooru";
	string booruDescription = "Small booru-like gallery written in D";
	URL siteURL = URL.parse("http://127.0.0.1:8080/");
	// Picture paths.
	Path publicPath = "public/";
	Path fullImagePath = "media/pictures/full/";
	Path thumbnailImagePath = "media/pictures/thumbnail/";
	Path previewImagePath = "media/pictures/preview/";
	Path avatar_path = "media/avatars/";
	// Pagination info.
	int postsOnPage = 2;

}