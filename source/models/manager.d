module models.manager;
import vibe.d;

/**
 * Class that stores values of type T in MongoDB database, providing inner counter for "id" field.
 */
class Manager(T)
{
	this()
	{
		database = connectMongoDB("127.0.0.1").getDatabase("Dbooru");
		// Initialize counter with 0 if don't have any value.
		auto bson = getCounters().findOne(["name":T.stringof]);
		if ( bson == Bson(null) ) {
			getCounters().insert(serializeToBson(["name":T.stringof, "value":"0"]));
		}
	}

	T[string] getAll()
	{
		T[string] ret;
		foreach(pic; getCollection().find()) {
			auto p = fromBson(pic);
			ret[p.name] = p;
		}
		return ret;
	}
	
	T get(int id)
	{
		return fromBson(getCollection().findOne(["id":id]));
	}

	T get(string[string] query)
	{
		return fromBson(getCollection().findOne(query));
	}

	bool have(string[string] query)
	{
		return getCollection().findOne(query) != Bson(null);
	}
	
	void add(T item)
	{
		logInfo(toBson(item).toString());
		getCollection();
		getCollection().insert(toBson(item));
	}
	
	void remove(int id)
	{
		getCollection().remove(["id":id]);
	}
	
	int getCount()
	{
		return cast(int) getCollection().find().count();
	}

	struct OptimisticLoop
	{
		string name;
		string value;
	}

	// Loop is represented as ["name":<type of stored value>,"value":<actual value of counter>].
	int getValue()
	{
		OptimisticLoop data;
		deserializeBson( data, getCounters().findOne(["name":T.stringof]) );
		return to!int(data.value);
	}

	void increment()
	{
		int val = getValue();
		getCounters().update(["name":T.stringof], ["$set":["value": to!string(to!int(val)+1)]]);
	}

private:
	MongoDatabase database;

	/// Gets collection where values of type T are stored.
	MongoCollection getCollection()
	{
		return database[T.stringof];
	}

	MongoCollection getCounters()
	{
		return database["counters"];
	}

	/// Pack value val to Bson.
	Bson toBson(T val)
	{
		Bson[string] ret;
		//logInfo(serializeToBson(this).toString());
		return serializeToBson(val);
	}

	/// Unpack Bson bson to type T.
	static T fromBson(Bson bson)
	{
		T ret;
		deserializeBson(ret, bson);
		return ret;
	}
};

