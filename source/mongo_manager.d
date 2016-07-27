module mongo_manager;

import vibe.d;

static class MongoManager
{
	static MongoDatabase database;
	
	this()
	{
		database = connectMongoDB("127.0.0.1").getDatabase("Dbooru");
	}
};
