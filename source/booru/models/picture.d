module booru.models.picture;
import std.datetime;
import vibe.d;
import derelict.freeimage.freeimage;
import booru.manager;

struct Picture
{
	int id;
	string name;
	string src;
	ulong image_width, image_height;
	string file_url, preview_url, thumbnail_url;
	ulong file_size;
	string[] tags; // Warning: tags here are stored as strings, but tags in general tag manager have Tag type.
	char rating;
	int score;
	string uploaded_by;
	DateTime upload_datetime;

	/+Bson toBson()
	{
		Bson[string] ret;
		/*foreach(m; __traits(allMembers, Picture)) {
			ret[m.stringof] = Bson(m);
		}*/
		
		//ret["name"] = name;
		// return Bson(ret);
		logInfo(serializeToBson(this).toString());
		return serializeToBson(this);
	}
	
	static typeof(this) fromBson(Bson bson)
	{
		/*auto ret = new Picture;
		ret.name = cast(string) bson["name"];
		return ret;*/
		typeof(this) ret;
		deserializeBson(ret, bson);
		return ret;
	}+/

}

/*class PictureManager : Manager!(Picture)
{

	override void add(Picture picture) 
	{
		super.add(picture);
	}
};*/

unittest 
{
	import std.format:format;
	auto pics = new Manager!Picture();
	Picture pic1, pic2;
	pic1.id = 1;
	pic1.name = "testname";
	pic1.src = "testsrc";
	pic2.id = 2;
	pic2.name = "test2name";
	pic2.src = "test2src";
	pics.add(pic1);
	pics.add(pic2);
	auto pics_array = pics.getAll();
	foreach (ref p; pics_array) {
		logInfo(format("> %s %s", p.name, p.src));
	}

}
