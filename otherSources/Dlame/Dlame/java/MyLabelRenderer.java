// $Id: MyLabelRenderer.java,v 1.1 2000/08/28 18:33:00 elwood Exp $

import java.awt.Component;
import javax.swing.JLabel;
import javax.swing.JTable;
import javax.swing.table.TableCellRenderer;

public class MyLabelRenderer extends JLabel implements TableCellRenderer
{
    public MyLabelRenderer(int column)
    {
	super();
	if(column == 2)
	    setHorizontalAlignment(javax.swing.SwingConstants.CENTER);
	else if(column < 6)
	    setHorizontalAlignment(javax.swing.SwingConstants.LEFT);
	else
	    setHorizontalAlignment(javax.swing.SwingConstants.RIGHT);
    }

    public Component getTableCellRendererComponent(JTable jt, Object value, boolean isSelected, boolean hasFocus, int row, int column)
    {
	setText((String)value);
	if(column < 6)
	    setHorizontalAlignment(javax.swing.SwingConstants.LEFT);
	else if(column == 2)
	    setHorizontalAlignment(javax.swing.SwingConstants.CENTER);
	else
	    setHorizontalAlignment(javax.swing.SwingConstants.RIGHT);
	return(this);
    }
}
