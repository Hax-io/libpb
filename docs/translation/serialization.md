Serialization
=============

This is just to show off the serialization method `serializeRecord(RecordType)` which returns a `JSONValue` struct:

```d
import std.algorithm.searching : canFind;
import std.string : cmp;

struct Person
{
	public string firstname, lastname;
	public int age;
	public string[] list;
	public JSONValue extraJSON;
	public EnumType eType;
}

Person p1;
p1.firstname  = "Tristan";
p1.lastname = "Kildaire";
p1.age = 23;
p1.list = ["1", "2", "3"];
p1.extraJSON = parseJSON(`{"item":1, "items":[1,2,3]}`);
p1.eType = EnumType.CAT;

JSONValue serialized = serializeRecord(p1);

string[] keys = serialized.object().keys();
assert(canFind(keys, "firstname") && cmp(serialized["firstname"].str(), "Tristan") == 0);
assert(canFind(keys, "lastname") && cmp(serialized["lastname"].str(), "Kildaire") == 0);
assert(canFind(keys, "age") && serialized["age"].integer() == 23);

debug(dbg)
{
	writeln(serialized.toPrettyString());
}
```