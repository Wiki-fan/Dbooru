module settings;

import vibe.d;

class BooruSettings
{
	const int thumbnail_size = 150;
	const int preview_size = 1000;
	string databaseURL = "mongodb://localhost/";
	string configName = "global";
	string booruName = "Dbooru";
	string booruDescription = "Small booru-like gallery written in D";
	URL siteURL = URL.parse("http://127.0.0.1:8080/");
	Path publicPath = "public/";
	Path fullImagePath = "media/pictures/full/";
	Path thumbnailImagePath = "media/pictures/thumbnail/";
	Path previewImagePath = "media/pictures/preview/";
	int postsOnPage = 2;
}