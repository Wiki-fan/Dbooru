module models.picture;
import vibe.d;
import models.manager;

struct Picture
{
	int id;
	string name;
	string src;
	int image_width, image_height;
	string file_url, preview_url, thumbnail_url;
	string[] tags;
	char rating;
	int score;

	
	this(int id, string name, string src)
	{
		this.id = id;
		this.name = name;
		this.src = src;
	}

	Bson toBson()
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
	}
	
};

unittest 
{
	auto pic = new Manager!Picture();
	pic.add(Picture(1, "testname", "testsrc"));
	pic.add(Picture(2, "test2name", "test2src"));
	auto pics = pic.getAll();
	foreach (ref p; pics) {
		logInfo(">"~ p.name ~ p.src);
	}

}
