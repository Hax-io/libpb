import std.json;
import std.stdio;
import std.net.curl;
import std.conv : to;

public final class PBException : Exception
{
	public enum ErrorType
	{
		CURL_NETWORK_ERROR,
		JSON_PARSE_ERROR
	}

	private ErrorType errType;
	
	this(ErrorType errType, string msg)
	{
		this.errType = errType;
		super("PBException("~to!(string)(errType)~"): "~msg);
	}
}

public class PocketBase
{
	private string pocketBaseURL;
	
	this(string pocketBaseURL = "http://127.0.0.1:8090/api/")
	{
		this.pocketBaseURL = pocketBaseURL;
	}

	public JSONValue listRecords(string table, ulong page = 1, ulong perPage = 30)
	{
		// Compute the query string
		string queryStr = "page="~to!(string)(page)~"&perPage="~to!(string)(perPage);
		
		try
		{
			string responseData = cast(string)get(pocketBaseURL~"collections/"~table~"/records?"~queryStr);
			JSONValue responseJSON = parseJSON(responseData);
			
			return responseJSON;
		}
		catch(CurlException e)
		{
			throw new PBException(PBException.ErrorType.CURL_NETWORK_ERROR, e.msg);
		}
		catch(JSONException e)
		{
			throw new PBException(PBException.ErrorType.JSON_PARSE_ERROR, e.msg);
		}
	}

	public JSONValue createRecord(string, RecordType)(string table, RecordType item)
	{
		HTTP httpSettings = HTTP();
		httpSettings.addRequestHeader("Content-Type", "application/json");
		
		// Serialize the record instance
		JSONValue serialized = serializeRecord(item);

		try
		{
			string responseData = cast(string)post(pocketBaseURL~"collections/"~table~"/records", serialized.toString(), httpSettings);
			JSONValue responseJSON = parseJSON(responseData);
			
			return responseJSON;
		}
		catch(CurlException e)
		{
			throw new PBException(PBException.ErrorType.CURL_NETWORK_ERROR, e.msg);
		}
		catch(JSONException e)
		{
			throw new PBException(PBException.ErrorType.JSON_PARSE_ERROR, e.msg);
		}
	}

	public JSONValue updateRecord(string, RecordType)(string table, RecordType item)
	{
		HTTP httpSettings = HTTP();
		httpSettings.addRequestHeader("Content-Type", "application/json");

		// Serialize the record instance
		JSONValue serialized = serializeRecord(item);

		try
		{
			string responseData = cast(string)patch(pocketBaseURL~"collections/"~table~"/records/"~item.id, serialized.toString(), httpSettings);
			JSONValue responseJSON = parseJSON(responseData);
			
			return responseJSON;
		}
		catch(CurlException e)
		{
			throw new PBException(PBException.ErrorType.CURL_NETWORK_ERROR, e.msg);
		}
		catch(JSONException e)
		{
			throw new PBException(PBException.ErrorType.JSON_PARSE_ERROR, e.msg);
		}
	}

	public static JSONValue serializeRecord(RecordType)(RecordType record)
	{
		import std.traits;
		import std.meta : AliasSeq;
		
		// Final JSON to submit
		JSONValue builtJSON;


		// Alias as to only expand later when used in compile-time
		alias structTypes = FieldTypeTuple!(RecordType);
		alias structNames = FieldNameTuple!(RecordType);
		alias structValues = record.tupleof;

		static foreach(cnt; 0..structTypes.length)
		{
			pragma(msg, structTypes[cnt]);
			pragma(msg, structNames[cnt]);
			// pragma(msg, structValues[cnt]);

			builtJSON[structNames[cnt]] = structValues[cnt];
		}
		
		writeln(builtJSON.toPrettyString());

		return builtJSON;
	}

	public static fromJSON(RecordType)(JSONValue jsonIn)
	{
		RecordType record;

		import std.traits;
		import std.meta : AliasSeq;

		// Alias as to only expand later when used in compile-time
		alias structTypes = FieldTypeTuple!(RecordType);
		alias structNames = FieldNameTuple!(RecordType);
		alias structValues = record.tupleof;

		static foreach(cnt; 0..structTypes.length)
		{
			pragma(msg, structTypes[cnt]);
			pragma(msg, structNames[cnt]);
			// pragma(msg, structValues[cnt]);

			//TODO: Add all integral types
			static if(__traits(isSame, mixin(structTypes[cnt]), int))
			{
				mixin("record."~structNames[cnt]) = cast(int)jsonIn[structNames[cnt]].integer();
			}
			static if(__traits(isSame, mixin(structTypes[cnt]), uint))
			{
				mixin("record."~structNames[cnt]) = cast(uint)jsonIn[structNames[cnt]].integer();
			}
			static if(__traits(isSame, mixin(structTypes[cnt]), ulong))
			{
				mixin("record."~structNames[cnt]) = cast(ulong)jsonIn[structNames[cnt]].integer();
			}
			static if(__traits(isSame, mixin(structTypes[cnt]), long))
			{
				mixin("record."~structNames[cnt]) = cast(long)jsonIn[structNames[cnt]].integer();
			}
			static if(__traits(isSame, mixin(structTypes[cnt]), string))
			{
				mixin("record."~structNames[cnt]) = jsonIn[structNames[cnt]].str();
				pragma(msg,"record."~structNames[cnt]);
			}
			static if(__traits(isSame, mixin(structTypes[cnt]), JSONValue))
			{
				mixin("record."~structNames[cnt]) = jsonIn[structNames[cnt]];
				pragma(msg,"record."~structNames[cnt]);
			}
			static if(__traits(isSame, mixin(structTypes[cnt]), bool))
			{
				mixin("record."~structNames[cnt]) = jsonIn[structNames[cnt]].boolean();
				pragma(msg,"record."~structNames[cnt]);
			}
			//FIXME: Not sure how to get array support going, very new to meta programming
			static if(__traits(isSame, mixin(structTypes[cnt]), mixin(structTypes[cnt])[]))
			{
				mixin("record."~structNames[cnt]) = jsonIn[structNames[cnt]].boolean();
				pragma(msg,"record."~structNames[cnt]);
			}	
		}

		return record;
	}

}




// Test serialization of a struct to JSON
unittest
{
	import std.algorithm.searching : canFind;
	import std.string : cmp;
	
	struct Person
	{
		public string firstname, lastname;
		public int age;
		public string[] list;
		public JSONValue extraJSON;
	}

	Person p1;
	p1.firstname  = "Tristan";
	p1.lastname = "Kildaire";
	p1.age = 23;
	p1.list = ["1", "2", "3"];
	p1.extraJSON = parseJSON(`{"item":1, "items":[1,2,3]}`);

	JSONValue serialized = PocketBase.serializeRecord(p1);

	string[] keys = serialized.object().keys();
	assert(canFind(keys, "firstname") && cmp(serialized["firstname"].str(), "Tristan") == 0);
	assert(canFind(keys, "lastname") && cmp(serialized["lastname"].str(), "Kildaire") == 0);
	assert(canFind(keys, "age") && serialized["age"].integer() == 23);
}


unittest
{
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

	writeln(person);

	assert(cmp(person.firstname, "Tristan") == 0);
	assert(cmp(person.lastname, "Kildaire") == 0);
	assert(person.age == 23);
	assert(person.isMale == true);
	//TODO: object test case, list test case
}
