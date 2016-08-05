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
		// Initialize counter with 0 if don't have any value. Notice that "hot" (without restarting server) removal of counters will be incorrect.
		auto bson = getCounters().findOne(["name":T.stringof]);
		if ( bson == Bson(null) ) {
			getCounters().insert(serializeToBson(["name":T.stringof, "value":"0"]));
		}
	}

	T[] getAll()
	{
		T[] ret;
		foreach(pic; getCollection().find()) {
			//logInfo(pic.toString());
			auto p = fromBson(pic);
			ret ~= p;
		}
		return ret;
	}

	T[] getAll(string[string] query)
	{
		T[] ret;
		foreach(pic; getCollection().find(query)) {
			//logInfo(pic.toString());
			auto p = fromBson(pic);
			ret ~= p;
		}
		return ret;
	}

	T[] getAll(Bson query)
	{
		T[] ret;
		foreach(pic; getCollection().find(query)) {
			//logInfo(pic.toString());
			auto p = fromBson(pic);
			ret ~= p;
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
		increment();
	}
	
	void remove(int id)
	{
		getCollection().remove(["id":id]);
	}

	struct OptimisticLoop
	{
		string name;
		string value;
	}

	// Loop is represented as ["name":<type of stored value>,"value":<actual value of counter>].
	int getNextIndex()
	{
		OptimisticLoop data;
		deserializeBson( data, getCounters().findOne(["name":T.stringof]) );
		return to!int(data.value);
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

	void increment()
	{
		int val = getNextIndex();
		getCounters().update(["name":T.stringof], ["$set":["value": to!string(to!int(val)+1)]]);
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

