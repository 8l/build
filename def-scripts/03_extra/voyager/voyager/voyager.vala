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

private class Program : Gtk.Application
{
  const string NAME        = "Voyager";
  const string VERSION     = "1.2.5";
  const string DESCRIPTION = _("Image browser in Vala and Gtk+3");
  const string ICON        = "voyager";
  const string[] AUTHORS   = { "Simargl <archpup-at-gmail-dot-com>", null };
  
  Gtk.Image image;
  Gdk.Pixbuf pixbuf;
  Gdk.Pixbuf pixbuf_scaled;
  Gtk.ApplicationWindow window;
  Gtk.HeaderBar headerbar;
  Gtk.TreeView treeview;
  Gtk.ListStore liststore;
  Gtk.MenuButton menubutton;
  Gtk.Revealer revealer;
  Gtk.ScrolledWindow scrolled_window_image;
  Gtk.ScrolledWindow scrolled_window_treeview;
  Gtk.Scale scale;
  Gtk.ToggleButton button_list;
  GLib.Settings settings;
  int width;
  int height;
  int screen_width;
  int screen_height;
  int pixbuf_width;
  int pixbuf_height;
  int saved_pixbuf_width;
  int saved_pixbuf_height;
  uint slideshow_delay;
  bool slideshow_active;
  string[] images;
  string file;
  double scale_current_value;
  private uint timeout_id;
  private const Gtk.TargetEntry[] targets = { {"text/uri-list", 0, 0} };
  
  int x_start;
  int y_start;
  int x_current;
  int y_current;
  int x_end;
  int y_end; 
  bool dragging;
  
  double hadj_value;
  double vadj_value;
  
  Gtk.Adjustment hadj;
  Gtk.Adjustment vadj;

  private const GLib.ActionEntry[] action_entries =
  {
    { "about",            action_about            },
    { "quit",             action_quit             },
    { "open",             action_open             },
    { "set-as-wallpaper", action_set_as_wallpaper },
    { "next-image",       action_next_image       },
    { "previous-image",   action_previous_image   },
    { "zoom-in",          action_zoom_in          },
    { "zoom-out",         action_zoom_out         },
    { "slideshow",        action_slideshow        },
    { "edit-with-gimp",   action_edit_with_gimp   },
    { "show-menu",        action_show_menu        }
  };

  private Program()
  {
    Object(application_id: "org.alphaos.voyager", flags: ApplicationFlags.HANDLES_OPEN);
    add_action_entries(action_entries, this);
  }

  public override void startup()
  {
    base.startup();

    var menu = new Menu();
    menu.append(_("About"),     "app.about");
    menu.append(_("Quit"),      "app.quit");

    set_app_menu(menu);
    
    add_accelerator("F10", "app.show-menu", null);

    settings = new GLib.Settings("org.alphaos.voyager.preferences");
    width = settings.get_int("width");
    height = settings.get_int("height");
    slideshow_delay = settings.get_uint("slideshow-delay");
    screen_width = Gdk.Screen.width();
    screen_height = Gdk.Screen.height();

    image = new Gtk.Image();

    // Buttons
    button_list = new Gtk.ToggleButton();
    button_list.valign = Gtk.Align.CENTER;
    button_list.set_image(new Gtk.Image.from_icon_name("view-list-symbolic", Gtk.IconSize.MENU));
    button_list.set_active(false);
    button_list.toggled.connect(action_reveal_list);

    var button_prev = new Gtk.Button.from_icon_name("go-previous-symbolic", Gtk.IconSize.MENU);
    var button_next = new Gtk.Button.from_icon_name("go-next-symbolic", Gtk.IconSize.MENU);
    button_prev.clicked.connect(action_previous_image);
    button_next.clicked.connect(action_next_image);

    var prev_next_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
    prev_next_box.pack_start(button_prev);
    prev_next_box.pack_start(button_next);
    prev_next_box.get_style_context().add_class("linked");
    prev_next_box.valign = Gtk.Align.CENTER;

    scale_current_value = 50;
    scale = new Gtk.Scale.with_range(Gtk.Orientation.HORIZONTAL, 0, 100, 10);
    scale.set_draw_value(false);
    scale.set_value(scale_current_value);
    scale.valign = Gtk.Align.CENTER;
    scale.set_size_request(100, 0);
    scale.value_changed.connect(scale_zoom_level);

    // HeaderBar & MenuButton
    var gear_menu = new GLib.Menu();
    var section_one = new GLib.Menu();
    var section_two = new GLib.Menu();
    var section_three = new GLib.Menu();
    var section_four = new GLib.Menu();
    
    section_one.append(_("Open"), "app.open");
    section_one.append(_("Set as Wallpaper"), "app.set-as-wallpaper");
    gear_menu.append_section(null, section_one);
    
    section_two.append(_("Next Image"), "app.next-image");
    section_two.append(_("Previous Image"), "app.previous-image");
    gear_menu.append_section(null, section_two);
    
    section_three.append(_("Zoom In"), "app.zoom-in");
    section_three.append(_("Zoom Out"), "app.zoom-out");
    gear_menu.append_section(null, section_three);
    
    section_four.append(_("Slideshow"), "app.slideshow");
    section_four.append(_("Edit With Gimp"), "app.edit-with-gimp");
    gear_menu.append_section(null, section_four);

    menubutton = new Gtk.MenuButton();
    menubutton.valign = Gtk.Align.CENTER;
    menubutton.set_use_popover(true);
    menubutton.set_menu_model(gear_menu);
    menubutton.set_image(new Gtk.Image.from_icon_name("emblem-system-symbolic", Gtk.IconSize.MENU));    

    headerbar = new Gtk.HeaderBar();
    headerbar.set_show_close_button(true);
    headerbar.set_title(NAME);
    headerbar.pack_start(button_list);
    headerbar.pack_start(prev_next_box);
    headerbar.pack_end(menubutton);
    headerbar.pack_end(scale);
    
    // TreeView
    var cell = new Gtk.CellRendererText();
    cell.set("font", "Cantarell 10");
    liststore = new Gtk.ListStore(2, typeof (string), typeof (string));
    
    treeview = new Gtk.TreeView();
    treeview.set_model(liststore);
    treeview.set_headers_visible(false);
    treeview.set_activate_on_single_click(true);
    treeview.row_activated.connect(show_selected_image);
    treeview.insert_column_with_attributes (-1, _("Name"), cell, "text", 0);

    // ScrolledWindow
    scrolled_window_image = new Gtk.ScrolledWindow(null, null);
    scrolled_window_image.set_policy(Gtk.PolicyType.AUTOMATIC, Gtk.PolicyType.AUTOMATIC);
    scrolled_window_image.expand = true;
    scrolled_window_image.set_size_request(250, 0);
    scrolled_window_image.add(image);
    
    scrolled_window_treeview = new Gtk.ScrolledWindow(null, null);
    scrolled_window_treeview.set_policy(Gtk.PolicyType.AUTOMATIC, Gtk.PolicyType.AUTOMATIC);
    scrolled_window_treeview.set_size_request(200, 0);
    scrolled_window_treeview.add(treeview);

    revealer = new Gtk.Revealer();
    revealer.add(scrolled_window_treeview);
    revealer.set_transition_duration(300);
    revealer.set_transition_type(Gtk.RevealerTransitionType.SLIDE_LEFT);

    var grid = new Gtk.Grid();
    grid.attach(revealer,              0, 0, 1, 1);
    grid.attach(scrolled_window_image, 1, 0, 1, 1);

    Gtk.drag_dest_set(grid, Gtk.DestDefaults.ALL, targets, Gdk.DragAction.COPY);
    grid.drag_data_received.connect(on_drag_data_received);

    // Window
    window = new Gtk.ApplicationWindow(this);
    window.add(grid);
    window.set_titlebar(headerbar);
    window.set_default_size(width, height);
    window.set_icon_name(ICON);
    window.show_all();
    window.key_press_event.connect(keyboard_events);
    window.scroll_event.connect(scrolled);
    window.delete_event.connect(() => { save_settings(); quit(); return true; });
    add_window(window);

    scrolled_window_image.add_events(Gdk.EventMask.ALL_EVENTS_MASK);
    scrolled_window_image.button_press_event.connect(mouse_button_press_events);
    scrolled_window_image.motion_notify_event.connect(mouse_motion_events);
    scrolled_window_image.button_release_event.connect(mouse_button_release_events);

    hadj = scrolled_window_image.get_hadjustment();
    vadj = scrolled_window_image.get_vadjustment();
  }

  public override void activate()
  {
    window.present();
  }

  public override void open(File[] files, string hint)
  {
    activate();
    foreach (File f in files)
    {
      file = f.get_uri().replace("file://", "").replace("file:/", "");
    }
    load_pixbuf_on_start(file);
    list_images(Path.get_dirname(file));
  }

  // Treeview
  private void list_images(string directory)
  {
    try
    {
      string output;
      Environment.set_current_dir(directory);
      Process.spawn_command_line_sync(" sh -c \"find '%s' -maxdepth 1 -name '*jpg' -o -name '*jpeg' -o -name '*png' -o -name '*bmp' -o -name '*svg' -o -name '*xpm' -o -name '*ico' -o -name '*JPG' -o -name '*JPEG' -o -name '*PNG' -o -name '*BMP' | sort -n\" ".printf(directory), out output);
      images = Regex.split_simple("[\n]", output, GLib.RegexCompileFlags.MULTILINE);
      add_images_to_liststore(images);
    }
    catch (GLib.Error e)
    {
      stderr.printf ("%s\n", e.message);
    }
  }
  
  private void add_images_to_liststore(string[] images_in_a_folder)
  {
    liststore.clear();
    Gtk.TreeIter iter;
    int img_number = 0;
    for (int i = 0; i < images_in_a_folder.length; i++)
    {
      if (images[i] != "")
      {
        var basename = Path.get_basename(images[i]);
        liststore.append(out iter);
        liststore.set(iter, 0, basename, 1, images[i]);
        if (images[i] == file)
        {
          img_number = i;
        }
      }
    }
    treeview.grab_focus();
    var path = new Gtk.TreePath.from_string(img_number.to_string());
    treeview.get_selection().select_path(path);
    treeview.scroll_to_cell(path, null, true, 0.5f, 0.0f);
  }

  private void show_selected_image()
  {
    Gtk.TreeIter iter;
    Gtk.TreeModel model;
    var selection = treeview.get_selection();
    selection.get_selected(out model, out iter);
    model.get(iter, 1, out file);
    load_pixbuf_on_start(file);
  }

  // load pixbuf with specified size, if width is smaller than 400px - then load at full size
  private void load_pixbuf(string pixbuf_name, int pixbuf_width, int pixbuf_height)
  {
    var basename = Path.get_basename(pixbuf_name);
    try
    {
      pixbuf = new Gdk.Pixbuf.from_file(pixbuf_name);
      if (pixbuf.get_width() <= 400)
      {
        image.set_from_pixbuf(pixbuf);
        pixbuf_scaled = pixbuf;
      }
      else
      { 
        try
        {
          pixbuf_scaled = new Gdk.Pixbuf.from_file_at_size(pixbuf_name, pixbuf_width, pixbuf_width);
          image.set_from_pixbuf(pixbuf_scaled);
        }
        catch(Error error)
        {
          stderr.printf("error: %s\n", error.message);
        }
      } 
      headerbar.set_title("%s - %s (%sx%s)".printf(NAME, basename, pixbuf.get_width().to_string(), pixbuf.get_height().to_string()));
    }
    catch(Error error)
    {
      stderr.printf("error: %s\n", error.message);
    }
  }

  // load pixbuf with specified size
  private void load_pixbuf_zoom(string pixbuf_name, int pixbuf_width, int pixbuf_height)
  {   
    try
    {
      pixbuf_scaled = new Gdk.Pixbuf.from_file_at_size(pixbuf_name, pixbuf_width, pixbuf_width);
      image.set_from_pixbuf(pixbuf_scaled);
    }
    catch(Error error)
    {
      stderr.printf("error: %s\n", error.message);
    }
  }

  // load pixbuf on start
  private void load_pixbuf_on_start(string pixbuf_name)
  {
    int width, height;
    window.get_size(out width, out height);
    pixbuf_height = 0;
    if ((window.get_window().get_state() & Gdk.WindowState.FULLSCREEN) != 0)
    {
      pixbuf_width = width;
    }
    else
    {
      pixbuf_width = scrolled_window_image.get_allocated_width();
    }
    load_pixbuf(pixbuf_name, pixbuf_width, pixbuf_height);
  }

  // Mouse EventButton Scroll
  private bool scrolled(Gdk.EventScroll event)
  {
    if (file != null)
    {
      if ((event.state & Gdk.ModifierType.CONTROL_MASK) > 0)
      {
        if (event.direction == Gdk.ScrollDirection.UP)
        { 
          zoom_image(true, 0.17, 0.07);
        }
        if (event.direction == Gdk.ScrollDirection.DOWN)
        {
          zoom_image(false, 0.17, 0.07);
        }
      }
    }
    return false;
  }

  private void zoom_image(bool plus, double zoom_larger, double zoom_smaller)
  {
    double change;
    double current_pixbuf_width = pixbuf_scaled.get_width();
    double current_pixbuf_height = pixbuf_scaled.get_height();
    change = current_pixbuf_width * zoom_larger;
    if (plus == true)
    {
      if (current_pixbuf_width > 640)
      {
        change = current_pixbuf_width * zoom_smaller;
      }
      load_pixbuf_zoom(file, (int)current_pixbuf_width + (int)change, (int)current_pixbuf_height + (int)change);
    }
    else
    {
      if (current_pixbuf_width > 15)
      {
        load_pixbuf_zoom(file, (int)current_pixbuf_width - (int)change, (int)current_pixbuf_height - (int)change);
      }
    }
  }

  private void scale_zoom_level()
  {
    if (file != null)
    {
      if (scale.get_value() > scale_current_value)
      {
        zoom_image(true, 0.17, 0.07);
      }
      else
      {
        zoom_image(false, 0.17, 0.07);
      }
      scale_current_value = scale.get_value();
    }
  }

  private void action_reveal_list()
  {
    if (button_list.get_active() == true)
    {
      revealer.set_reveal_child(true);
    }
    else
    {
      revealer.set_reveal_child(false);
    }
  }

  // Mouse EventButton Press
  private bool mouse_button_press_events(Gdk.EventButton event)
  {
    if (file != null)
    {
      if (event.type == Gdk.EventType.2BUTTON_PRESS)
      {
        if ((window.get_window().get_state() & Gdk.WindowState.FULLSCREEN) != 0)
        {
          full_screen_exit();
        }
        else
        {
          full_screen_switch();
        }
      } 
    }
    if (event.button == 1)
    {
      var device = Gtk.get_current_event_device();
      if(device != null)
      {
        event.window.get_device_position(device, out x_start, out y_start, null);
        event.window.set_cursor(new Gdk.Cursor(Gdk.CursorType.FLEUR));
      }
      dragging = true;
      hadj_value = hadj.get_value();
      vadj_value = vadj.get_value();
    }
    return false;
  }

  // release
  public bool mouse_button_release_events(Gdk.EventButton event)
  {
    if (event.type == Gdk.EventType.BUTTON_RELEASE)
    {
      if (event.button == 1)
      {
        var device = Gtk.get_current_event_device();
        if(device != null)
        {
          event.window.get_device_position(device, out x_end, out y_end, null);
          event.window.set_cursor(null);
        }  
        dragging = false;
        return false;
      }
    }
    return false;
  }

  // motion
  public bool mouse_motion_events(Gdk.EventMotion event)
  {
    if (dragging == true)
    {  
      var device = Gtk.get_current_event_device();
      if(device != null)
      {
        event.window.get_device_position(device, out x_current, out y_current, null);
        event.window.set_cursor(null);
      } 
      
      int x_diff = x_start - x_current;
      int y_diff = y_start - y_current;
      
      hadj.set_value(hadj_value + x_diff);
      vadj.set_value(vadj_value + y_diff);
    }
    return false;
  }

  private void full_screen_switch()
  {
    scrolled_window_treeview.hide();
    window.fullscreen();
    saved_pixbuf_width = (int)pixbuf_scaled.get_width();
    saved_pixbuf_height = (int)pixbuf_scaled.get_height();
    load_pixbuf(file, screen_width, screen_height);
  }
  
  private void full_screen_exit()
  {  
    scrolled_window_treeview.show();
    window.unfullscreen();
    load_pixbuf(file, saved_pixbuf_width, saved_pixbuf_height);
  }

  // Keyboard EventKey Press
  private bool keyboard_events(Gdk.EventKey event)
  {
    if (file != null)
    {
      string key = Gdk.keyval_name(event.keyval);
      if(key=="Escape")
      {
        if ((window.get_window().get_state() & Gdk.WindowState.FULLSCREEN) != 0)
        {
          full_screen_exit();
        }
      }
      if(key=="F11")
      {
        if ((window.get_window().get_state() & Gdk.WindowState.FULLSCREEN) != 0)
        {
          full_screen_exit();
        }
        else
        {
          full_screen_switch();
        }
      }
      if(key=="Right" || key=="Down")
      {
        action_next_image();
      }
      if(key=="Left" || key=="Up")
      {
        action_previous_image();
      }
    }
    return false;
  } 

  // Drag Data
  private void on_drag_data_received(Gdk.DragContext drag_context, int x, int y, Gtk.SelectionData data, uint info, uint time) 
  {
    foreach(string uri in data.get_uris())
    {
      file = uri.replace("file://", "").replace("file:/", "");
      file = Uri.unescape_string(file);
      load_pixbuf_on_start(file);
      list_images(Path.get_dirname(file));
    }
    Gtk.drag_finish(drag_context, true, false, time);
  }

  private void save_settings()
  {
    window.get_size(out width, out height);
    settings.set_int("width", width);
    settings.set_int("height", height);
    GLib.Settings.sync();
  }

  private void action_open()
  {
    var dialog = new Gtk.FileChooserDialog(_("Open"), window, Gtk.FileChooserAction.OPEN,
                                        "gtk-cancel", Gtk.ResponseType.CANCEL,
                                        "gtk-open", Gtk.ResponseType.ACCEPT);
    dialog.set_transient_for(window);
    dialog.set_select_multiple(false);
    if (file != null)
    {
      dialog.set_current_folder(Path.get_dirname(file));
    }
    if (dialog.run() == Gtk.ResponseType.ACCEPT)
    {
      file = dialog.get_filename();
      load_pixbuf_on_start(file);
      list_images(Path.get_dirname(file));
    }
    dialog.destroy();
  }

  private void action_set_as_wallpaper()
  {
    if (file != null)
    {
      var gnome_settings = new GLib.Settings("org.gnome.desktop.background");
      gnome_settings.set_string("picture-uri", file);
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
  }

  private void action_next_image()
  {
    if (file != null)
    {
      Gtk.TreeIter iter;
      Gtk.TreeModel model;
      var selection = treeview.get_selection();
      selection.get_selected(out model, out iter);
      if (model.iter_next(ref iter))
      {
        selection.select_iter(iter);
      }
      else
      {
        model.get_iter_first(out iter);
        selection.select_iter(iter);
      }
      treeview.scroll_to_cell(model.get_path(iter), null, false, 0.0f, 0.0f);
      show_selected_image();
    }
  }

  private void action_previous_image()
  {
    if (file != null)
    {
      Gtk.TreeIter iter;
      Gtk.TreeModel model;
      int children;
      var selection = treeview.get_selection();
      selection.get_selected(out model, out iter);
      if (model.iter_previous(ref iter))
      {
        selection.select_iter(iter);
      }
      else
      {
        children = model.iter_n_children(null);
        model.iter_nth_child(out iter, null, children - 1);
        selection.select_iter(iter);
      }
      treeview.scroll_to_cell(model.get_path(iter), null, false, 0.0f, 0.0f);
      show_selected_image();
    }
  }

  private void action_zoom_in()
  {
    if (file != null)
    {
      zoom_image(true, 0.30, 0.20);
    }
  }

  private void action_zoom_out()
  {
    if (file != null)
    {
      zoom_image(false, 0.25, 0.15);
    }
  }

  private void action_slideshow()
  {
    if (file != null)
    {
      if (slideshow_active == false)
      {
        timeout_id = GLib.Timeout.add(slideshow_delay, (GLib.SourceFunc)action_next_image, 0);
        slideshow_active = true;
      } 
      else
      {
        if (timeout_id > 0)
        {
          GLib.Source.remove(timeout_id);
        }
        slideshow_active = false;
      }
    }
  }

  private void action_edit_with_gimp()
  {
    if (file != null)
    {
      try
      {
        Process.spawn_command_line_async("gimp %s".printf(file));
      }
      catch(Error error)
      {
        stderr.printf("error: %s\n", error.message);
      }
    }
  }

  private void action_show_menu()
  {
    if ((window.get_window().get_state() & Gdk.WindowState.FULLSCREEN) == 0)
    {
      menubutton.set_active(true);
    }
  }
  
  private void action_about()
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

  private void action_quit()
  {
    save_settings();
    this.quit();
  }

  private static int main (string[] args)
  {
    Program app = new Program();
    return app.run(args);
  }
}
