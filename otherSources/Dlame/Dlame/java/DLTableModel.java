// $Id: DLTableModel.java,v 1.1 2000/08/28 18:30:38 elwood Exp $
import java.util.Enumeration;
import java.util.Hashtable;
import javax.swing.table.DefaultTableModel;

public class DLTableModel extends DefaultTableModel
{
    static String ColumnNames[] = {"CPU", "Client", "Busy", "Album", "Artist", "Song", "% completed", "rate", "minrate", "avgrate", "maxrate"};
    Hashtable CPUS;
    String bla[];

    public DLTableModel(Hashtable h)
    {
	int i;

	CPUS = h;
	setColumnIdentifiers(ColumnNames);
	fireTableStructureChanged();
    }

    public String getColumName(int col)
    {
	System.out.println("gcn("+col+") called");
	if(col < ColumnNames.length)
	{
	    System.out.println(ColumnNames[col]);
	    return(ColumnNames[col]);
	}
	else
	    return("Hallo");
    }

    public Class getColumnClass(int col)
    {
	try
	{
	    if(col == 2)
		return(Class.forName("java.lang.Boolean"));
	    else if(col == 6)
		return(Class.forName("java.lang.Float"));
	    else 
		return(Class.forName("java.lang.String"));
	}
	catch(Exception ex)
	{
	    return(null);
	}
    }

    public int getColumnCount()
    {
	return(ColumnNames.length);
	//	return(10);
    }

    public int getRowCount()
    {
	if(CPUS == null)
	    return(0);
	else
	    return(CPUS.size());
    }
    
    public Object getValueAt(int row, int col)
    {
	int i;
	Object o=null;
	Enumeration e = CPUS.elements();
	for(i=0; i <= row; i++)
	    o = e.nextElement();
	RlameCPU rcpu = (RlameCPU)o;
	if(o == null)
	    return("NULL");
	else
	    switch(col)
	    {
	    case 0:
		return(rcpu.getConnName());
	    case 1:
		return(rcpu.getClientName());
	    case 2:
		return(rcpu.getBusy());
	    case 3:
		return(rcpu.getAlbum());
	    case 4:
		return(rcpu.getArtist());
	    case 5:
		return(rcpu.getSong());
	    case 6:
		return(rcpu.getPercent());
	    case 7:
		return(rcpu.getRate());
	    case 8:
		return(rcpu.getMinrate());
	    case 9:
		return(rcpu.getAvgrate());
	    case 10:
		return(rcpu.getMaxrate());
	    }
	return(null);
    }
}	
