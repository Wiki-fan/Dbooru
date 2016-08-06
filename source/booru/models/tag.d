module booru.models.tag;
import vibe.d;
import booru.manager;

struct Tag
{
	this(string name, int count)
	{
		this.name = name;
		this.count = count;
	}

	string name;
	int count;
}