// $Id: RlConnection.java,v 1.2 2000/10/07 19:24:19 elwood Exp $
import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.io.PrintWriter;
import java.lang.Thread;
import java.net.Socket;
import java.util.Hashtable;
import java.util.StringTokenizer;


public class RlConnection extends Thread
{
    private Hashtable cpus;
    private BufferedReader br;
    private PrintWriter pw;
    private JMonitor jm;

    public RlConnection(String hostname, int port, Hashtable h, JMonitor j)
    {
	cpus = h;
	jm = j;
	try
	{
	    String line;
	    // NetzWerkVebindung
	    Socket s = new Socket(hostname, port);
	    pw = new PrintWriter(s.getOutputStream(), true);
	    br = new BufferedReader(new InputStreamReader(s.getInputStream()));
	    // GetStatus fuer die ersten Daten und sendstatusupdates damit wir mehr erhalten
	    pw.println("getstatus");
	    parseCPULine(br.readLine());
	    while(br.ready())
	    {
		String sl = br.readLine();
		System.out.println("S: "+sl);
		parseCPULine(sl);
	    }
	    // Komponenten zusammenbauen (Tabelle und CloseButton)
	    pw.println("sendstatusupdates");
	}
	catch(Exception ex)
	{
	    System.err.println("Exception while creating socket "+ex);
	}
    }

    public void doUpdates()
    {
	while(true)
	{
	    try
	    {
		String line = br.readLine();
		jm.updateSent(parseCPULine(line));
	    }
	    catch(java.io.IOException je)
	    {
		System.out.println("Error while reading next line");
	    }
	}
    }

    public boolean parseCPULine(String line)
    {
	RlameCPU r;
	boolean wasnew=false;

	if(line.startsWith("CPU"))
	{
	    StringTokenizer st = new StringTokenizer(line.substring(4), "|");
	    String host = st.nextToken();
	    if(host.indexOf("@") > -1)
	    {
		StringTokenizer hosts = new StringTokenizer(host, "@");
		String cpu    = hosts.nextToken();
		String client = hosts.nextToken();
		String cpuhost = new String(cpu.substring(0, cpu.indexOf(":")));
		int    cpuport = new Integer(cpu.substring(cpu.indexOf(":") + 1)).intValue();
		String clienthost = new String(client.substring(0, client.indexOf(":")));
		int    clientport = new Integer(client.substring(client.indexOf(":") + 1)).intValue();

		if(cpus.get(cpuhost+":"+cpuport) == null)
		{
		    r = new RlameCPU(cpuhost, cpuport);
		    wasnew = true;
		    cpus.put(r.getConnName(), r);
		}
		else
		    r = (RlameCPU)cpus.get(cpuhost+":"+cpuport);
		r.clienthost = clienthost;
		r.clientport = clientport;
		String test=r.getClientName();
		try
		{
		    String album = st.nextToken();
		    if(!album.startsWith("ripping"))
		    {
			if(!album.equals("")&&!album.equals("idle"))
			{
			    r.album = album;
			    r.artist = st.nextToken();
			    r.song = st.nextToken();
			    r.busy = true;
			    r.finished = new Integer(st.nextToken()).intValue();
			    String sstr = st.nextToken();
			    if(!sstr.equals(""))
				r.size = new Integer(sstr).intValue();
			    r.updateRate(new Float(st.nextToken()).floatValue());
			}
		    }
		    else
		    {
			r.album = album;
			r.artist = "";
			r.song = "";
			r.finished = 0;
			r.size = 0;
		    }
		}
		catch(java.util.NoSuchElementException nsee)
		{
		    r.busy = false;
		    r.percent = -1;
		    r.size = -1;
		    r.finished = -1;
		    r.rate = -1;
		}
	    }
	    else
	    {
		int port = new Integer(st.nextToken()).intValue();
		if(cpus.get(host+":"+port) == null)
		{
		    r = new RlameCPU(host, port);
		    wasnew = true;
		    cpus.put(r.getConnName(), r);
		}
		else
		    r = (RlameCPU)cpus.get(host+":"+port);
		r.busy = false;
		r.percent = 0;
		r.size = -1;
		r.finished = -1;
		r.rate = -1;
		r.album = new String("");
		r.artist = new String("");
		r.song = new String("");
		r.clienthost = new String("");
		r.clientport = 0;
	    }
	}
	else if(line.startsWith("DELCPU"))
	{
	    StringTokenizer st = new StringTokenizer(line.substring(7), "|");
	    String host = st.nextToken();
	    int port = new Integer(st.nextToken()).intValue();
	    cpus.remove(host+":"+port);
	    wasnew = true;
	}
	return(wasnew);
    }
}
