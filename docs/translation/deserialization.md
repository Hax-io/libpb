Deserialization
===============

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

Person person = fromJSON!(Person)(json);

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