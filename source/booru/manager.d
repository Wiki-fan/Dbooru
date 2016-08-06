module booru.manager;
import vibe.d;
import booru.settings, booru.mongo_manager;

/**
 * Class that stores values of type T in MongoDB database, providing inner counter for "id" field.
 */
class Manager(T)
{
	Paginator!T paginator;
	BooruSettings settings;

	this(BooruSettings settings, MongoManager mongoManager)
	{
		collection = mongoManager.getCollection(T.stringof);
		counters = mongoManager.getCollection("counters");
		// Initialize counter with 0 if don't have any value. Notice that "hot" (without restarting server) removal of counters will be incorrect.
		immutable auto bson = counters.findOne(["name":T.stringof]);
		if ( bson == Bson(null) ) {
			counters.insert(serializeToBson(["name":T.stringof, "value":"0"]));
		}
		this.settings = settings;
		paginator = new Paginator!T(this.settings.postsOnPage);
	}

	T[] getAll(Bson query = Bson.emptyObject)
	{
		T[] ret;
		foreach(pic; collection.find(query)) {
			auto p = fromBson(pic);
			ret ~= p;
		}
		return ret;
	}

	T[] getPage(Bson query, int page, out int totalCount)
	{
		T[] ret;
		// Workaround because there isn't MongoCursor.size() function. Applying count() to cursor removes all items from it.
		auto cursor = collection.find(query);
		totalCount = cast(int)(collection.find(query).count());
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
		return fromBson(collection.findOne(["id":id]));
	}

	T get(string[string] query)
	{
		return fromBson(collection.findOne(query));
	}

	bool have(string[string] query)
	{
		return collection.findOne(query) != Bson(null);
	}

	ulong getCount(Bson query)
	{
		return collection.count(query);
	}
	
	void add(T item)
	{
		logInfo("Adding item: "~toBson(item).toString());
		collection.insert(toBson(item));
		increment();
	}
	
	void remove(int id)
	{
		collection.remove(["id":id]);
	}

	// Loop is represented as ["name":<type of stored value>,"value":<actual value of counter>].
	int getNextIndex()
	{
		OptimisticLoop data;
		deserializeBson( data, counters.findOne(["name":T.stringof]) );
		return to!int(data.value);
	}

private:
	MongoCollection collection;
	MongoCollection counters;

	/// Pack value val to Bson.
	Bson toBson(T val)
	{
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
		
		void refresh(int elementsCount)
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
		
		int getPrevPage() { return page == 1? 1:page-1; }
		
		int getNextPage() { return page==lastPage?lastPage:page+1; }

		int getFirstPage() {return 1; }

		int getLastPage() { return lastPage; }

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
		immutable int val = getNextIndex();
		counters.update(["name":T.stringof], ["$set":["value": to!string(to!int(val)+1)]]);
	}
}

