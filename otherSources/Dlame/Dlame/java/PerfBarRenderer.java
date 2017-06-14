// $Id: PerfBarRenderer.java,v 1.2 2000/10/07 19:23:57 elwood Exp $

import java.awt.Component;
import java.text.DecimalFormat;
import javax.swing.JProgressBar;
import javax.swing.JTable;
import javax.swing.table.TableCellRenderer;

public class PerfBarRenderer extends JProgressBar implements TableCellRenderer
{
    int index=0;
    DecimalFormat df;

    public PerfBarRenderer()
    {
	super(HORIZONTAL, 0, 100);
	setString("0 %");
	setStringPainted(true);
	df = new DecimalFormat("###.00");
    }

    public Component getTableCellRendererComponent(JTable jt, Object value, boolean isSelected, boolean hasFocus, int row, int column)
    {
	float f;

	f = ((Float)value).floatValue();
	setValue((int)f);
	setString(df.format(f)+" %");
	fireStateChanged();
	return(this);
    }
}
