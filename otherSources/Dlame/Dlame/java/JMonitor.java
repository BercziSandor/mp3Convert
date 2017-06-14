// $Id: JMonitor.java,v 1.2 2000/10/07 19:23:28 elwood Exp $ 

import java.awt.Dimension;
import java.util.Hashtable;
import java.util.StringTokenizer;
import javax.swing.JButton;
import javax.swing.JFrame;
import javax.swing.JLabel;
import javax.swing.JPanel;
import javax.swing.JTable;
import javax.swing.table.TableColumn;

public class JMonitor extends JFrame
{
    Hashtable h = new Hashtable();
    DLTableModel d;
    JTable jt;
    RlConnection rlc;

    public JMonitor(String hostname, int port)
    {
	super("DlameMonitor");

	getContentPane().setLayout(new java.awt.BorderLayout());
	rlc = new RlConnection(hostname, port, h, this);
	d = new DLTableModel(h);
	jt = new JTable(d);
	jt.setPreferredScrollableViewportSize(new Dimension(900,70));
	JPanel panel = new JPanel();
	JButton closebutton = new JButton("Close");
	panel.add(closebutton);
	closebutton.addActionListener (new java.awt.event.ActionListener () {
            public void actionPerformed (java.awt.event.ActionEvent evt) {
              quit();
            }
          }
        );
	getContentPane().add(new javax.swing.JScrollPane(jt), "Center");
	getContentPane().add(panel, "South");
	pack();
	d.fireTableStructureChanged();
	setVisible(true);
	for(int i = 0; i < jt.getColumnCount(); i++)
	{
	    TableColumn tc = jt.getColumn(jt.getColumnName(i));
	    if(i < 2)
	    {
		tc.setWidth(120);
		tc.setCellRenderer(new MyLabelRenderer(i));
	    }
	    else if((i == 2) || (i == 6))
	    {
		if(i == 6)
		    tc.setCellRenderer(new PerfBarRenderer());
		tc.setWidth(50);
	    }
	    else if(i > 6)
	    {
		tc.setCellRenderer(new MyLabelRenderer(i));
		tc.setWidth(75);
	    }
	    else
		tc.setWidth(150);
	}
	rlc.doUpdates();
    }

    public JMonitor()
    {
	this("localhost", (short)8888);
    }

    public synchronized void updateSent(boolean value)
    {
	if(value)
	    d.fireTableStructureChanged();
	d.fireTableDataChanged();
	/*	for(int i=0; i < jt.getColumnCount(); i++)
		System.out.println(i+":"+(jt.getColumn(jt.getColumnName(i))).getCellRenderer());*/
    }

    public void quit()
    {
	rlc.stop();
	System.exit(0);
    }

    public static void main(String argv[])
    {
	if(argv.length < 1)
	{
	    new JMonitor("localhost", (short)8888);
	}
	else
	{
	    StringTokenizer st = new StringTokenizer(argv[0], ":");
	    String hostname = st.nextToken();
	    String pn = st.nextToken();
	    JMonitor jm = new JMonitor(hostname, (new Integer(pn)).intValue());
	    jm.setVisible(true);
	}
    }
}
