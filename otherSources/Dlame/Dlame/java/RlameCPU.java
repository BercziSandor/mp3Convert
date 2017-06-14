// $Id: RlameCPU.java,v 1.2 2000/10/07 19:24:49 elwood Exp $

import java.text.DecimalFormat;
import java.util.NoSuchElementException;
import java.util.StringTokenizer;

public class RlameCPU
{
    String host, clienthost, song, artist, album;
    int port, clientport, finished, size, samplecount;
    float avgrate, minrate, maxrate, sumrates, rate, percent;
    boolean busy;
    DecimalFormat df;

    public RlameCPU(String line)
    {
	StringTokenizer st = new StringTokenizer(line.substring(4), "|");
	host = st.nextToken();
	port = new Integer(st.nextToken()).intValue();
	setDefaults();
    }

    public RlameCPU(String h, int p)
    {
	host = h;
	port = p;
	setDefaults();
    }
    
    private void setDefaults()
    {
	samplecount = 0;
	minrate = 100000000;
	maxrate = 0;
	avgrate = 0;
	busy = false;
	df = new DecimalFormat("########.00");
    }

    public void updateRate(float r)
    {
	rate = r;

	if(rate > 0)
	{
	    samplecount++;
	    if(rate < minrate)
		minrate = rate;
	    if(rate > maxrate)
		maxrate = rate;
	    
	    sumrates += rate;
	    avgrate = sumrates/samplecount;
	}
    }

    public String getConnName()
    {
	return(host+":"+port);
    }

    public String getClientName()
    {
	
	if(clienthost != null)
	    return(clienthost+":"+clientport);
	else
	    return("");
    }
    
    public String getAlbum()
    {
	if(album != null)
	    return(album);
	else
	    return("");
    }

    public String getArtist()
    {
	if(artist != null)
	    return(artist);
	else
	    return("");
    }

    public String getSong()
    {
	if(song != null)
	    return(song);
	else
	    return("");
    }

    public Float getPercent()
    {	
	if(size > 0)
	{
	    percent = (float)finished;
	    percent = percent / size;
	    percent = percent * 100;
	    //	    return(percent + " %");
	    return(new Float(percent));
	}
	else
	    return(new Float(0));
    }

    public String getRate()
    {
	if(rate > 0)
	    return(df.format(rate) + " b/sec");
	else
	return("");
    }

    public String getMinrate()
    {
	if(minrate < 10000000)
	    return(df.format(minrate) + " b/sec");
	else
	    return("");
    }

    public String getAvgrate()
    {
	if(avgrate > 0)
	    return(df.format(avgrate) + " b/sec");
	else
	    return("");
    }

    public String getMaxrate()
    {
	if(maxrate > 0)
	    return(df.format(maxrate) + " b/sec");
	else
	    return("");
    }

    public Boolean getBusy()
    {
	return(new Boolean(busy));
	/*	if(busy)
	    return("x");
	else
	return(" ");*/
    }
}
