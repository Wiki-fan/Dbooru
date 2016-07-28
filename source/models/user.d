module models.user;
import vibe.d;
import models.bson_mixin;

mixin template BsonConvertible()
{
	Bson toBson()
	{
		Bson[string] ret;
		//logInfo(serializeToBson(this).toString());
		//return serializeToBson(this);
		return Bson();
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
}; 

/*unittest {
	User usr;
	Bson bson = usr.toBson();
}*/