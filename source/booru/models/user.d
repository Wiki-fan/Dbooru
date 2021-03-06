module booru.models.user;
import std.datetime;
import vibe.d;

mixin template BsonConvertible()
{
	Bson toBson()
	{
		Bson[string] ret;
		//logInfo(serializeToBson(this).toString());
		return serializeToBson(this);
	}
	
	static typeof(this) fromBson(Bson bson)
	{
		typeof(this) ret;
		deserializeBson(ret, bson);
		return ret;
	}
}


struct User
{
	bool loggedIn = false;
	string name;
	string nickname;
	string password;
	DateTime registration_datetime;
	string avatar_url;

	//mixin BsonConvertible;
	/*Bson toBson()
	{
		Bson[string] ret;
		//logInfo(serializeToBson(this));
		return serializeToBson(this);
	}*/
	
	/*static typeof(this) fromBson(Bson bson)
	{
		typeof(this) ret;
		deserializeBson(ret, bson);
		return ret;
	}*/
}
