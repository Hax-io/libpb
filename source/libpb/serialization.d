module libpb.serialization;

import std.json;
import std.conv : to;
import std.traits : FieldTypeTuple, FieldNameTuple;

public JSONValue serializeRecord(RecordType)(RecordType record)
{		
	// Final JSON to submit
	JSONValue builtJSON;

	// Alias as to only expand later when used in compile-time
	alias structTypes = FieldTypeTuple!(RecordType);
	alias structNames = FieldNameTuple!(RecordType);
	alias structValues = record.tupleof;

	static foreach(cnt; 0..structTypes.length)
	{
		debug(dbg)
		{
			pragma(msg, structTypes[cnt]);
			pragma(msg, structNames[cnt]);
			// pragma(msg, structValues[cnt]);
		}


		static if(__traits(isSame, mixin(structTypes[cnt]), int))
		{
			builtJSON[structNames[cnt]] = structValues[cnt];
		}
		else static if(__traits(isSame, mixin(structTypes[cnt]), uint))
		{
			builtJSON[structNames[cnt]] = structValues[cnt];
		}
		else static if(__traits(isSame, mixin(structTypes[cnt]), ulong))
		{
			builtJSON[structNames[cnt]] = structValues[cnt];
		}
		else static if(__traits(isSame, mixin(structTypes[cnt]), long))
		{
			builtJSON[structNames[cnt]] = structValues[cnt];
		}
		else static if(__traits(isSame, mixin(structTypes[cnt]), string))
		{
			builtJSON[structNames[cnt]] = structValues[cnt];
		}
		else static if(__traits(isSame, mixin(structTypes[cnt]), JSONValue))
		{
			builtJSON[structNames[cnt]] = structValues[cnt];
		}
		else static if(__traits(isSame, mixin(structTypes[cnt]), bool))
		{
			builtJSON[structNames[cnt]] = structValues[cnt];
		}
		else
		{
			debug(dbg)
			{
				pragma(msg, "Yaa");	
			}
			builtJSON[structNames[cnt]] = to!(string)(structValues[cnt]);
		}
	}


	return builtJSON;
}

// Test serialization of a struct to JSON
private enum EnumType
{
	DOG,
	CAT
}
unittest
{
	import std.algorithm.searching : canFind;
	import std.string : cmp;
	import std.stdio : writeln;
	
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
}
