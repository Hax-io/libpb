libpb
=====

#### _PocketBase wrapper with serializer/deserializer support_

----

## Example usage

### Server initiation

Firstly we create a new PocketBase instance to manage our server:

```d
PocketBase pb = new PocketBase("http://127.0.0.1:8090/api/");
```

### Serialization

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

JSONValue serialized = PocketBase.serializeRecord(p1);

string[] keys = serialized.object().keys();
assert(canFind(keys, "firstname") && cmp(serialized["firstname"].str(), "Tristan") == 0);
assert(canFind(keys, "lastname") && cmp(serialized["lastname"].str(), "Kildaire") == 0);
assert(canFind(keys, "age") && serialized["age"].integer() == 23);

debug(dbg)
{
	writeln(serialized.toPrettyString());
}
```

### Deserialization

This is to show off deserialization method `fromJSON(RecordType)(JSONValue jsonIn)` which returns a struct of type `RecordType` (so far most features are implemented):

```d
import std.string : cmp;
	
struct Person
{
	public string firstname, lastname;
	public int age;
	public bool isMale;
	public JSONValue obj;
	public int[] list;
}
	
JSONValue json = parseJSON(`{
"firstname" : "Tristan",
"lastname": "Kildaire",
"age": 23,
"obj" : {"bruh":1},
"isMale": true,
"list": [1,2,3]
}
`);

Person person = PocketBase.fromJSON!(Person)(json);

debug(dbg)
{
	writeln(person);	
}
	

assert(cmp(person.firstname, "Tristan") == 0);
assert(cmp(person.lastname, "Kildaire") == 0);
assert(person.age == 23);
assert(person.isMale == true);
assert(person.obj["bruh"].integer() == 1);
//TODO: list test case
```

### Record management

Below we have a few calls like create and delete:

```d
PocketBase pb = new PocketBase();

struct Person
{
	string id;
	string name;
	int age;
}

Person p1 = Person();
p1.name = "Tristan Gonzales";
p1.age = 23;

Person recordStored = pb.createRecord("dummy", p1);
pb.deleteRecord("dummy", recordStored.id);

recordStored = pb.createRecord("dummy", p1);
pb.deleteRecord("dummy", recordStored);
```

## Development

### Unit tests

To run tests you will want to enable the `pragma`s and `writeln`s. therefore pass the `dbg` flag in as such:

```bash
dub test -ddbg
```

Run pocketbase on the default port and then use the schema provided as `dummy.json` to test with (in a collection named `dummy`).

## License

See [LICENSE](LICENSE)
