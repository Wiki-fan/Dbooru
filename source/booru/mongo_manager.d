module booru.mongo_manager;
import vibe.d;
import booru.settings;

class MongoManager
{
	MongoDatabase database;

	this(BooruSettings settings)
	{
		/*string database;
		MongoClientSettings dbsettings;
		if (parseMongoDBUrl(dbsettings, settings.databaseURL))
			database = dbsettings.database;
		logInfo("Using database "~database);*/
		database = connectMongoDB(settings.databaseURL).getDatabase(settings.databaseName);
	}

	MongoCollection getCollection(string name)
	{
		return database[name];
	}
}