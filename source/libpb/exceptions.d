module libpb.exceptions;

public abstract class PBException : Exception
{	
	this(string message = "")
	{
		super("PBException: "~message);
	}
}

public final class RecordNotFoundException : PBException
{
	public const string offendingTable;
	public const string offendingId;
	this(string table, string id)
	{
		this.offendingTable = table;
		this.offendingId = id;

		super("Could not find record '"~id~"' in table '"~offendingTable~"'");
	}
}

public final class NotAuthorized : PBException
{
	public const string offendingTable;
	public const string offendingId;
	this(string table, string id)
	{
		this.offendingTable = table;
		this.offendingId = id;
	}
}

public final class ValidationRequired : PBException
{
	public const string offendingTable;
	public const string offendingId;
	this(string table, string id)
	{
		this.offendingTable = table;
		this.offendingId = id;
	}
}


/** 
 * NetworkException
 *
 * Thrown on an unhandled curl error
 */
public final class NetworkException : PBException
{
	this()
	{

	}
}

public final class PocketBaseParsingException : PBException
{

}


public final class RemoteFieldMissing : PBException
{
	this()
	{
		
	}
}