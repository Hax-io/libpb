module libpb.driver;

import std.json;
import std.stdio;
import std.net.curl;
import std.conv : to;
import std.string : cmp;
import libpb.exceptions;
import libpb.serialization;
import libpb.deserialization;


private mixin template AuthTokenHeader(alias http, PocketBase pbInstance)
{
	// Must be an instance of HTTP from `std.curl`
	static assert(__traits(isSame, typeof(http), HTTP));
	
	void InitializeAuthHeader()
	{
		// Check if the given PocketBase instance as an authToken
		if(pbInstance.authToken.length > 0)
		{
			// Then add the authaorization header
			http.addRequestHeader("Authorization", pbInstance.getAuthToken());
		}
	}
	
}

public class PocketBase
{
	private string pocketBaseURL;
	private string authToken;
	
	/** 
	 * Constructs a new PocketBase instance with
	 * the default settings
	 */
	this(string pocketBaseURL = "http://127.0.0.1:8090/api/", string authToken = "")
	{
		this.pocketBaseURL = pocketBaseURL;
		this.authToken = authToken;
	}

	public void setAuthToken(string authToken)
	{
		if(cmp(authToken, "") != 0)
		{
			this.authToken = authToken;	
		}
	}

	public string getAuthToken()
	{
		return this.authToken;
	}

	/** 
	 * List all of the records in the given table
	 *
	 * Params:
	 *   table = the table to list from
	 *   page = the page to look at (default is 1)
	 *   perPage = the number of items to return per page (default is 30)
	 *
	 * Returns: A list of type <code>RecordType</code>
	 */
	public RecordType[] listRecords(RecordType)(string table, ulong page = 1, ulong perPage = 30, string filter = "")
	{
		// Set authorization token if setup
		HTTP httpSettings = HTTP();
		mixin AuthTokenHeader!(httpSettings, this);
		InitializeAuthHeader();
				
		RecordType[] recordsOut;

		// Compute the query string
		string queryStr = "page="~to!(string)(page)~"&perPage="~to!(string)(perPage);

		// If there is a filter then perform the needed escaping
		if(cmp(filter, "") != 0)
		{
			// For the filter, make sure to add URL escaping to the `filter` parameter
			import etc.c.curl : curl_escape;
			import std.string : toStringz, fromStringz;
			char* escapedParameter = curl_escape(toStringz(filter), cast(int)filter.length);
			if(escapedParameter is null)
			{
				debug(dbg)
				{
					writeln("Invalid return from curl_easy_escape");
				}
				throw new NetworkException();
			}

			// Convert back to D-string (the filter)
			filter = cast(string)fromStringz(escapedParameter);
		}

		// Append the filter
		queryStr ~= cmp(filter, "") == 0 ? "" : "&filter="~filter;
		
		try
		{
			string responseData = cast(string)get(pocketBaseURL~"collections/"~table~"/records?"~queryStr, httpSettings);
			JSONValue responseJSON = parseJSON(responseData);
			JSONValue[] returnedItems = responseJSON["items"].array();
			foreach(JSONValue returnedItem; returnedItems)
			{
				recordsOut ~= fromJSON!(RecordType)(returnedItem);
			}
			
			return recordsOut;
		}
		catch(HTTPStatusException e)
		{
			if(e.status == 403)
			{
				throw new NotAuthorized(table, null);
			}
			else
			{
				throw new NetworkException();
			}
		}
		catch(CurlException e)
		{
			debug(dbg)
			{
				writeln("curl");
				writeln(e);
			}
			
			throw new NetworkException();
		}
		catch(JSONException e)
		{
			throw new PocketBaseParsingException();
		}
	}

	/** 
	 * Creates a record in the given table
	 *
	 * Params:
	 *   table = the table to create the record in
	 *   item = The Record to create
	 *
	 * Returns: An instance of the created <code>RecordType</code>
	 */
	public RecordType createRecord(string, RecordType)(string table, RecordType item, bool isAuthCollection = false)
	{
		idAbleCheck(item);

		RecordType recordOut;
		
		// Set authorization token if setup
		HTTP httpSettings = HTTP();
		mixin AuthTokenHeader!(httpSettings, this);
		InitializeAuthHeader();

		// Set the content type
		httpSettings.addRequestHeader("Content-Type", "application/json");
		
		// Serialize the record instance
		JSONValue serialized = serializeRecord(item);

		try
		{
			string responseData = cast(string)post(pocketBaseURL~"collections/"~table~"/records", serialized.toString(), httpSettings);
			JSONValue responseJSON = parseJSON(responseData);
			
			// On creation of a record in an "auth" collection the email visibility
			// will initially be false, therefore fill in a blank for it temporarily
			// now as to not make `fromJSON` crash when it sees an email field in
			// a struct and tries to look the the JSON key "email" when it isn't present
			//
			// A password is never returned (so `password` and `passwordConfirm` will be left out)
			//
			// The above are all assumed to be strings, if not then a runtime error will occur
			// See (issue #3)
			if(isAuthCollection)
			{
				responseJSON["email"] = "";
				responseJSON["password"] = "";
				responseJSON["passwordConfirm"] = "";
			}
			
			recordOut = fromJSON!(RecordType)(responseJSON);
			
			return recordOut;
		}
		catch(HTTPStatusException e)
		{
			if(e.status == 403)
			{
				throw new NotAuthorized(table, item.id);
			}
			else if(e.status == 400)
			{
				throw new ValidationRequired(table, item.id);
			}
			else
			{
				// TODO: Fix this
				throw new NetworkException();
			}
		}
		catch(CurlException e)
		{
			throw new NetworkException();
		}
		catch(JSONException e)
		{
			throw new PocketBaseParsingException();
		}
	}

	/** 
	 * View the given record by id
	 *
	 * Params:
	 *   table = the table to lookup the record in
	 *   id = the id to lookup the record by
	 *
	 * Returns: The found record of type <code>RecordType</code>
	 */
	public RecordType viewRecord(RecordType)(string table, string id)
	{
		RecordType recordOut;

		// Set authorization token if setup
		HTTP httpSettings = HTTP();
		mixin AuthTokenHeader!(httpSettings, this);
		InitializeAuthHeader();

		try
		{
			string responseData = cast(string)get(pocketBaseURL~"collections/"~table~"/records/"~id, httpSettings);
			JSONValue responseJSON = parseJSON(responseData);

			recordOut = fromJSON!(RecordType)(responseJSON);
			
			return recordOut;
		}
		catch(HTTPStatusException e)
		{
			if(e.status == 404)
			{
				throw new RecordNotFoundException(table, id);
			}
			else
			{
				// TODO: Fix this
				throw new NetworkException();
			}
		}
		catch(CurlException e)
		{
			throw new NetworkException();
		}
		catch(JSONException e)
		{
			throw new PocketBaseParsingException();
		}
	}

	/** 
	 * Updates the given record in the given table, returning the
	 * updated record
	 *
	 * Params:
	 *   table = tabe table to update the record in
	 *   item = the record of type <code>RecordType</code> to update
	 *
	 * Returns: The updated <code>RecordType</code>
	 */
	public RecordType updateRecord(string, RecordType)(string table, RecordType item)
	{
		idAbleCheck(item);

		RecordType recordOut;

		// Set authorization token if setup
		HTTP httpSettings = HTTP();
		mixin AuthTokenHeader!(httpSettings, this);
		InitializeAuthHeader();

		// Set the content type
		httpSettings.addRequestHeader("Content-Type", "application/json");

		// Serialize the record instance
		JSONValue serialized = serializeRecord(item);

		try
		{
			string responseData = cast(string)patch(pocketBaseURL~"collections/"~table~"/records/"~item.id, serialized.toString(), httpSettings);
			JSONValue responseJSON = parseJSON(responseData);

			recordOut = fromJSON!(RecordType)(responseJSON);
			
			return recordOut;
		}
		catch(HTTPStatusException e)
		{
			if(e.status == 404)
			{
				throw new RecordNotFoundException(table, item.id);
			}
			else if(e.status == 403)
			{
				throw new NotAuthorized(table, item.id);
			}
			else if(e.status == 400)
			{
				throw new ValidationRequired(table, item.id);
			}
			else
			{
				// TODO: Fix this
				throw new NetworkException();
			}
		}
		catch(CurlException e)
		{
			throw new NetworkException();
		}
		catch(JSONException e)
		{
			throw new PocketBaseParsingException();
		}
	}

	/** 
	 * Deletes the provided record by id from the given table
	 *
	 * Params:
	 *   table = the table to delete the record from
	 *   id = the id of the record to delete
	 */
	public void deleteRecord(string table, string id)
	{
		// Set authorization token if setup
		HTTP httpSettings = HTTP();
		mixin AuthTokenHeader!(httpSettings, this);
		InitializeAuthHeader();
		
		try
		{
			del(pocketBaseURL~"collections/"~table~"/records/"~id, httpSettings);
		}
		catch(HTTPStatusException e)
		{
			if(e.status == 404)
			{
				throw new RecordNotFoundException(table, id);
			}
			else
			{
				// TODO: Fix this
				throw new NetworkException();
			}
		}
		catch(CurlException e)
		{
			throw new NetworkException();
		}
	}

	/** 
	 * Deletes the provided record from the given table
	 *
	 * Params:
	 *   table = the table to delete from
	 *   record = the record of type <code>RecordType</code> to delete
	 */
	public void deleteRecord(string, RecordType)(string table, RecordType record)
	{
		idAbleCheck(record);
		deleteRecord(table, record.id);
	}

	public static void idAbleCheck(RecordType)(RecordType record)
	{
		static if(__traits(hasMember, record, "id"))
		{
			static if(__traits(isSame, typeof(record.id), string))
			{
				// Do nothing as it is a-okay
			}
			else
			{
				// Must be a string
				pragma(msg, "The `id` field of the record provided must be of type string");
				static assert(false);
			}
		}
		else
		{
			// An id field is required (TODO: ensure not a function identifier)
			pragma(msg, "The provided record must have a `id` field");
			static assert(false);
		}
	}

	// TODO: Implement the streaming functionality
	private void stream(string table)
	{
		
	}
}

unittest
{
	import core.thread : Thread, dur;
	import std.string : cmp;
	
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
	Thread.sleep(dur!("seconds")(3));
	recordStored.age = 46;
	recordStored = pb.updateRecord("dummy", recordStored);
	assert(recordStored.age == 46);
	Thread.sleep(dur!("seconds")(3));

	Person recordFetched = pb.viewRecord!(Person)("dummy", recordStored.id);
	assert(recordFetched.age == 46);
	assert(cmp(recordFetched.name, "Tristan Gonzales") == 0);
	assert(cmp(recordFetched.id, recordStored.id) == 0);

	pb.deleteRecord("dummy", recordStored);

	Person[] people = [Person(), Person()];
	people[0].name = "Abby";
	people[1].name = "Becky";

	people[0] = pb.createRecord("dummy", people[0]);
	people[1] = pb.createRecord("dummy", people[1]);

	Person[] returnedPeople = pb.listRecords!(Person)("dummy");
	foreach(Person returnedPerson; returnedPeople)
	{
		debug(dbg)
		{
			writeln(returnedPerson);
		}
		pb.deleteRecord("dummy", returnedPerson);
	}

	try
	{
		recordFetched = pb.viewRecord!(Person)("dummy", people[0].id);
		assert(false);
	}
	catch(RecordNotFoundException e)
	{
		assert(cmp(e.offendingTable, "dummy") == 0 && e.offendingId == people[0].id);
	}
	catch(Exception e)
	{
		assert(false);
	}

	try
	{
		recordFetched = pb.updateRecord("dummy", people[0]);
		assert(false);
	}
	catch(RecordNotFoundException e)
	{
		assert(cmp(e.offendingTable, "dummy") == 0 && e.offendingId == people[0].id);
	}
	catch(Exception e)
	{
		assert(false);
	}

	try
	{
		pb.deleteRecord("dummy", people[0]);
		assert(false);
	}
	catch(RecordNotFoundException e)
	{
		assert(cmp(e.offendingTable, "dummy") == 0 && e.offendingId == people[0].id);
	}
	catch(Exception e)
	{
		assert(false);
	}
}

unittest
{
	import core.thread : Thread, dur;
	import std.string : cmp;
	
	PocketBase pb = new PocketBase();

	struct Person
	{
		string id;
		string email;
		string username;
		string password;
		string passwordConfirm;
	}

	Person p1;
	p1.email = "deavmi@redxen.eu";
	p1.username = "deavmi";
	p1.password = "bigbruh1111";
	p1.passwordConfirm = "bigbruh1111";

	p1 = pb.createRecord("dummy_auth", p1, true);
	pb.deleteRecord("dummy_auth", p1);
}

unittest
{
	import core.thread : Thread, dur;
	import std.string : cmp;
	
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

	Person p2 = Person();
	p2.name = p1.name~"2";
	p2.age = p1.age;

	p1 = pb.createRecord("dummy", p1);
	p2 = pb.createRecord("dummy", p2);

	Person[] people = pb.listRecords!(Person)("dummy", 1, 30, "(id='"~p1.id~"')");
	assert(people.length == 1);
	assert(cmp(people[0].id, p1.id) == 0);

	pb.deleteRecord("dummy", p1);
	people = pb.listRecords!(Person)("dummy", 1, 30, "(id='"~p1.id~"')");
	assert(people.length == 0);

	people = pb.listRecords!(Person)("dummy", 1, 30, "(id='"~p2.id~"' && age=24)");
	assert(people.length == 0);

	people = pb.listRecords!(Person)("dummy", 1, 30, "(id='"~p2.id~"' && age=23)");
	assert(people.length == 1 && cmp(people[0].id, p2.id) == 0);
	
	pb.deleteRecord("dummy", p2);
}
