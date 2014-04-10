/*  Copyright (c) alphaOS
 *  Written by simargl <archpup-at-gmail-dot-com>
 *  
 *  This program is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or
 *  (at your option) any later version.
 *  
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *  
 *  You should have received a copy of the GNU General Public License
 *  along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

class Program : Gtk.Window
{
  const string NAME = "Wallpaper Setter";
  const string VERSION = "0.9.5";
  const string DESCRIPTION = _("Change your desktop wallpaper");
  const string ICON = "preferences-desktop-wallpaper";
  const string[] AUTHORS = { "Simargl <archpup-at-gmail-dot-com>", null };
  
  Gtk.Window window;
  GLib.Settings settings;
  Gdk.Pixbuf pixbuf;
  Gtk.ListStore liststore;
  Gtk.TreeView view;
  string[] wallpapers;
  string[] images_dir;
  Gtk.ScrolledWindow scrolled;
  private const Gtk.TargetEntry[] targets = { {"text/uri-list", 0, 0} };
  
  public Program()
  {
    load_settings();
    wallpaper_setter_gui();
  }
  
  private void load_settings()
  {
    settings = new GLib.Settings("org.alphaos.wpset.preferences");
    images_dir = settings.get_strv("images-dir");
  }
  
  void wallpaper_setter_gui()
  {
    var cell_pixbuf = new Gtk.CellRendererPixbuf();
    var cell_name = new Gtk.CellRendererText();
    
    view = new Gtk.TreeView();
    view.row_activated.connect(apply_selected_image);
    view.set_headers_visible(false);
    
    liststore = new Gtk.ListStore (3, typeof (Gdk.Pixbuf), typeof (string), typeof (string));
    
    view.set_model(liststore);
    view.insert_column_with_attributes (-1, "Image", cell_pixbuf, "pixbuf", 0);
    view.insert_column_with_attributes (-1, "Filename", cell_name, "text", 1);
    
    for (int i = 0; i < images_dir.length; i++)
    {
      list_images(images_dir[i]);
    }
    var menuitem_add = new Gtk.MenuItem.with_label(_("Add folder"));
    menuitem_add.activate.connect(add_directory_dialog);

    var menuitem_reset = new Gtk.MenuItem.with_label(_("Reset list"));
    menuitem_reset.activate.connect(reset_liststore);   
    
    var menuitem_separator = new Gtk.SeparatorMenuItem();
    
    var menuitem_about = new Gtk.MenuItem.with_label(_("About"));
    menuitem_about.activate.connect(about_dialog);
    
    var menu = new Gtk.Menu();
    menu.append(menuitem_add);
    menu.append(menuitem_reset);
    menu.append(menuitem_separator);
    menu.append(menuitem_about);
    menu.show_all();
    
    var menubutton = new Gtk.MenuButton();
    menubutton.valign = Gtk.Align.CENTER;
    menubutton.set_popup(menu);
    menubutton.set_image(new Gtk.Image.from_icon_name("emblem-system-symbolic", Gtk.IconSize.MENU));
    
    var headerbar = new Gtk.HeaderBar();
    headerbar.set_show_close_button(true);
    headerbar.set_title(NAME);
    headerbar.pack_end(menubutton);
    
    scrolled = new Gtk.ScrolledWindow(null, null);
    scrolled.set_policy(Gtk.PolicyType.AUTOMATIC, Gtk.PolicyType.ALWAYS);
    scrolled.expand = true;
    scrolled.set_size_request(395, 406);
    scrolled.add(view);
    
    var grid = new Gtk.Grid();
    grid.attach(scrolled,           0, 0, 3, 1);
    grid.set_column_spacing(5);
    grid.set_row_spacing(5);
    
    window = new Gtk.Window();
    window.set_icon_name(ICON);
    window.window_position = Gtk.WindowPosition.CENTER;
    window.set_titlebar(headerbar);
    window.add(grid);
    window.set_border_width(5);
    window.show_all();
    window.destroy.connect(Gtk.main_quit);
    
    Gtk.drag_dest_set(grid, Gtk.DestDefaults.ALL, targets, Gdk.DragAction.COPY);
    grid.drag_data_received.connect(on_drag_data_received);
  }  
  
  void list_images(string directory)
  {
    try
    {
      string output;
      Environment.set_current_dir(directory);
      Process.spawn_command_line_sync(" sh -c \"find %s -maxdepth 1 -name '*jpg' -o -name '*png' -o -name '*bmp' | sort -n\" ".printf(directory), out output);
      wallpapers = Regex.split_simple("[\n]", output, GLib.RegexCompileFlags.MULTILINE);
      add_pixbuf_to_liststore(wallpapers);
    }
    catch (GLib.Error e)
    {
      stderr.printf ("%s\n", e.message);
    }
  }
  
  void add_pixbuf_to_liststore(string[] images_in_a_folder)
  {
    Gtk.TreeIter iter;
    for (int i = 0; i < images_in_a_folder.length; i++)
    {
      if (wallpapers[i] != "")
      {
        var basename = Path.get_basename(wallpapers[i]);
        try
        {
          pixbuf = new Gdk.Pixbuf.from_file_at_size(wallpapers[i], 175, 175);
        }
        catch(Error error)
        {
          stderr.printf("error: %s\n", error.message);
        }
        liststore.append(out iter);
        liststore.set(iter, 0, pixbuf, 1, basename, 2, wallpapers[i]);
      }
    }
  }
  
  private void add_directory_dialog()
  {
    var dialog = new Gtk.FileChooserDialog(_("Add folder..."), window, Gtk.FileChooserAction.SELECT_FOLDER,
                                         "gtk-cancel", Gtk.ResponseType.CANCEL,
                                         "gtk-open", Gtk.ResponseType.ACCEPT);
    dialog.set_transient_for(window);
    if (dialog.run() == Gtk.ResponseType.ACCEPT)
    {
      images_dir += (dialog as Gtk.FileChooserDialog).get_current_folder();
      list_images(images_dir[images_dir.length - 1]);
      settings.set_strv("images-dir", images_dir);
    }
    dialog.destroy();
  }

  private void apply_selected_image()
  {
    string selected;
    Gtk.TreeIter iter;
    Gtk.TreeModel model;
    var selection = view.get_selection();
    selection.get_selected(out model, out iter);
    model.get(iter, 2, out selected);
    var gnome_settings = new GLib.Settings("org.gnome.desktop.background");
    gnome_settings.set_string("picture-uri", "file://".concat(selected));
    GLib.Settings.sync();
    try
    {
      Process.spawn_command_line_sync("wpset-shell --set");
    }
    catch(Error error)
    {
      stderr.printf("error: %s\n", error.message);
    }
  }
  
  private void reset_liststore()
  {
    liststore.clear();
    images_dir = {"/usr/share/backgrounds"};
    list_images(images_dir[0]);
    view.grab_focus();
    settings.set_strv("images-dir", images_dir);
    GLib.Settings.sync();
  }

  // Drag Data
  private void on_drag_data_received(Gdk.DragContext drag_context, int x, int y, Gtk.SelectionData data, uint info, uint time) 
  {
    foreach(string uri in data.get_uris())
    {
      string file;
      file = uri.replace("file://", "").replace("file:/", "");
      file = Uri.unescape_string(file);
      images_dir += Path.get_dirname(file);
      list_images(images_dir[images_dir.length - 1]);
      settings.set_strv("images-dir", images_dir);
      GLib.Settings.sync();
    }
    Gtk.drag_finish(drag_context, true, false, time);
  }
  
  private void about_dialog()
  {
    var about = new Gtk.AboutDialog();
    about.set_program_name(NAME);
    about.set_version(VERSION);
    about.set_comments(DESCRIPTION);
    about.set_logo_icon_name(ICON);
    about.set_authors(AUTHORS);
    about.set_copyright("Copyright \xc2\xa9 alphaOS");
    about.set_website("http://alphaos.tuxfamily.org");
    about.set_property("skip-taskbar-hint", true);
    about.set_transient_for(window);
    about.license_type = Gtk.License.GPL_3_0;
    about.run();
    about.hide();
  }

  public static int main (string[] args)
  {
    Gtk.init(ref args);
    new Program();
    Gtk.main();
    return 0;
  }
}
