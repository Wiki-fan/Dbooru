module booru.tag_string;
import std.string;

// Custom implementation of tag query string. Standard delimeter in query is ',', can import strings using any delimiter character.
struct TagString
{
	this(string tags, string delim)
	{
		foreach(tag; tags.split(delim))
			this.tags[tag] = true;
	}
	
	string toQueryString(string delim = ",")
	{
		return ("%-(%s"~delim~"%)").format(tags.keys);
	}
	
	void add(string tag)
	{
		tags[tag] = true;
	}
	
	void remove(string tag)
	{
		tags.remove(tag);
	}
	
private:
	bool[string] tags;
}

unittest {
	// Incorrect.
	TagString ts = TagString("first, second, third", ", ");
	assert(ts.toQueryString() == "first,second,third");
	ts.add("test");
	assert(ts.toQueryString(" ") == "first second third test");
	ts.remove("first");
	assert(ts.toQueryString(", ") == "second, third, test");
}
