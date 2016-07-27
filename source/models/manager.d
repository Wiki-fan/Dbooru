module models.manager;
import vibe.d;

class Manager(T)
{
	this()
	{
		database = connectMongoDB("127.0.0.1").getDatabase("Dbooru");
	}

	Bson toBson(T val)
	{
		Bson[string] ret;
		//logInfo(serializeToBson(this).toString());
		return serializeToBson(val);
	}
	
	static T fromBson(Bson bson)
	{
		T ret;
		deserializeBson(ret, bson);
		return ret;
	}
	
	T[string] getAll()
	{
		T[string] ret;
		foreach(pic; getCollection().find()) {
			auto p = T.fromBson(pic);
			ret[p.name] = p;
		}
		return ret;
	}
	
	T get(int id)
	{
		return T.fromBson(getCollection().findOne(["id":id]));
	}

	T get(string[string] query)
	{
		return T.fromBson(getCollection().findOne(query));
	}

	bool have(string[string] query)
	{
		return getCollection().findOne(query) != Bson(null);
	}
	
	void add(T pic)
	{
		getCollection().insert(pic.toBson());
	}
	
	void remove(int id)
	{
		getCollection().remove(["id":id]);
	}
	
	int getCount()
	{
		return cast(int) getCollection().find().count();
	}
	
private:
	MongoDatabase database;
	MongoCollection getCollection()
	{
		return database[T.stringof];
	}
};

