module models.manager;
import vibe.d;
import settings;
/**
 * Class that stores values of type T in MongoDB database, providing inner counter for "id" field.
 */
class Manager(T)
{
	Paginator!T paginator;
	BooruSettings settings;
	this(BooruSettings settings)
	{
		database = connectMongoDB("127.0.0.1").getDatabase("Dbooru");
		// Initialize counter with 0 if don't have any value. Notice that "hot" (without restarting server) removal of counters will be incorrect.
		auto bson = getCounters().findOne(["name":T.stringof]);
		if ( bson == Bson(null) ) {
			getCounters().insert(serializeToBson(["name":T.stringof, "value":"0"]));
		}
		this.settings = settings;
		paginator = new Paginator!T(this.settings.postsOnPage);
	}

	T[] getAll(Bson query = Bson.emptyObject)
	{
		T[] ret;
		foreach(pic; getCollection().find(query)) {
			auto p = fromBson(pic);
			ret ~= p;
		}
		return ret;
	}

	T[] getPage(Bson query, int page, out int totalCount)
	{
		T[] ret;
		// Workaround because there isn't MongoCursor.size() function. Applying count() to cursor removes all items from it.
		auto cursor = getCollection().find(query);
		totalCount = cast(int)(getCollection().find(query).count());
		// For some reasons we shouldn't use commented variant as it produces wrong results.
		//cursor = cursor.limit(page*paginator.elementsOnPage).skip((page-1)*paginator.elementsOnPage);
		cursor = cursor.skip((page-1)*paginator.elementsOnPage).limit(paginator.elementsOnPage);
		foreach(pic; cursor) {
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

	ulong getCount(Bson query)
	{
		return getCollection().count(query);
	}
	
	void add(T item)
	{
		logInfo("Adding item: "~toBson(item).toString());
		getCollection();
		getCollection().insert(toBson(item));
		increment();
	}
	
	void remove(int id)
	{
		getCollection().remove(["id":id]);
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
	MongoCollection getCollection() { return database[T.stringof]; }

	MongoCollection getCounters() { return database["counters"]; }

	/// Pack value val to Bson.
	Bson toBson(T val)
	{
		Bson[string] ret;
		return serializeToBson(val);
	}

	/// Unpack Bson bson to type T.
	static T fromBson(Bson bson)
	{
		T ret;
		deserializeBson(ret, bson);
		return ret;
	}

	// Class that does all pagination-specific math. Init it with elements count before use.
	class Paginator(T)
	{
		int elementsCount;
		int elementsOnPage;
		int page;
		int lastPage;
		
		this( int elementsOnPage)
		{
			this.elementsOnPage = elementsOnPage;
		}
		
		void init(int elementsCount)
		{
			this.elementsCount = elementsCount;
			lastPage = elementsCount % elementsOnPage == 0? elementsCount/elementsOnPage : elementsCount/elementsOnPage+1;
		}
		
		int setPageFromQuery(HTTPServerRequest req)
		{
			auto query_page = ("page" in req.query);
			if (query_page != null) page = to!int(*query_page); else page = 1;
			return page;
		}
		
		int getPrevPage()
		{
			return page == 1? 1:page-1;
		}
		
		int getNextPage()
		{
			return page==lastPage?lastPage:page+1;
		}

		int getFirstPage()
		{
			return 1;
		}

		int getLastPage()
		{
			return lastPage;
		}

		/*int getMinElemOfPage(int page)
		{
			return (page-1)*elementsOnPage;
		}

		int getMaxElemOfPage(int page)
		{
			return page*elementsOnPage-1;
		}*/

		int[] getNeighbourhood(int epsilon)
		{
			int[] ret;
			for (int i = page-epsilon; i<=page+epsilon; ++i) {
				if (i <=getLastPage() && i >= 1) {
					ret ~= i;
				}
			}
			return ret;
		}
	}

	/// Represents loop going incrementally only forward. So deletions of elements will not cause counter to decrease.
	struct OptimisticLoop
	{
		string name;
		string value;
	}

	void increment()
	{
		int val = getNextIndex();
		getCounters().update(["name":T.stringof], ["$set":["value": to!string(to!int(val)+1)]]);
	}
};

