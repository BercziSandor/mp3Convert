// $Id$

import java.awt.Component;
import javax.swing.JCheckBox;
import javax.swing.JTable;
import javax.swing.table.TableCellRenderer;

public class CheckBoxRenderer extends JCheckBox implements TableCellRenderer
{
    public Component getTableCellRendererComponent(JTable jt, Object value, boolean isSelected, boolean hasFocus, int row, int column)
    {
	System.out.println("v:"+value);
	setSelected(((Boolean)value).booleanValue());
	return(this);
    }
}
