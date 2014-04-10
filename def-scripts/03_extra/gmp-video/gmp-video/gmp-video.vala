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

using LibmpControl;

private class Program : Gtk.Window
{
  const string NAME        = "GMP Video";
  const string VERSION     = "0.9.1";
  const string DESCRIPTION = _("Mpv frontend in Vala and GTK3");
  const string ICON        = "gmp-video";
  const string[] AUTHORS   = { "Simargl <archpup-at-gmail-dot-com>", null };
  
  long xid;
  GLib.Settings settings;
  Gtk.Button button_restart;
  Gtk.Button button_pause;
  Gtk.Button button_rewind;
  Gtk.Button button_forward;
  Gtk.Button button_stop;
  Gtk.HeaderBar headerbar;
  Gtk.VolumeButton button_volume;
  Gtk.DrawingArea drawing_area;
  Gtk.Grid buttons_grid;
  Gtk.Menu context_menu;
  Gtk.Window window;
  private const Gtk.TargetEntry[] targets = { {"text/uri-list", 0, 0} };
  
  string FIFO;
  string OUTPUT;
  string file;
  string subtitle_file;
  int drawing_area_width;
  int drawing_area_height;
  string video_mode;
  string subtitle_color;
  double subtitle_scale;
  string subtitle_fuzziness;

  public Program()
  {
    load_settings();
    draw_ui();
  }

  private void load_settings()
  {
    settings = new GLib.Settings("org.alphaos.gmp-video.preferences");
    drawing_area_width = settings.get_int("drawing-area-width");
    drawing_area_height = settings.get_int("drawing-area-height");
    video_mode = settings.get_string("video-mode");
    subtitle_color = settings.get_string("subtitle-color");
    subtitle_scale = settings.get_double("subtitle-scale");
    subtitle_fuzziness = settings.get_string("subtitle-fuzziness");
  }
  
  private void draw_ui()
  { 
    string random_number = GLib.Random.int_range(1000, 5000).to_string();
    FIFO = "/tmp/gmp_video_fifo_" + random_number;
    OUTPUT = "/tmp/gmp_video_output_" + random_number;
    
    drawing_area = new Gtk.DrawingArea();
    drawing_area.set_size_request(drawing_area_width, drawing_area_height);
    drawing_area.add_events(Gdk.EventMask.BUTTON_PRESS_MASK);
    drawing_area.add_events(Gdk.EventMask.SCROLL_MASK);
    drawing_area.button_press_event.connect(mouse_button_press_events);
    drawing_area.scroll_event.connect(mouse_button_scroll_events);
    drawing_area.set_vexpand(true);
    drawing_area.set_hexpand(true);
    
    button_restart = new Gtk.Button.from_icon_name("view-refresh-symbolic", Gtk.IconSize.LARGE_TOOLBAR);
    button_pause = new Gtk.Button.from_icon_name("media-playback-pause-symbolic", Gtk.IconSize.LARGE_TOOLBAR);
    button_rewind = new Gtk.Button.from_icon_name("media-skip-backward-symbolic", Gtk.IconSize.LARGE_TOOLBAR);
    button_forward = new Gtk.Button.from_icon_name("media-skip-forward-symbolic", Gtk.IconSize.LARGE_TOOLBAR);
    button_stop = new Gtk.Button.from_icon_name("media-playback-stop-symbolic", Gtk.IconSize.LARGE_TOOLBAR);
    button_volume = new Gtk.VolumeButton();
    button_volume.use_symbolic = true;
    button_volume.set_value(1.00);

    button_restart.clicked.connect(() => { gmp_video_start_playback(); });
    button_pause.clicked.connect(() => { mpv_send_command(FIFO, "cycle pause"); });
    button_rewind.clicked.connect(() => { mpv_send_command(FIFO, "seek -15"); });
    button_forward.clicked.connect(() => { mpv_send_command(FIFO, "seek +15"); });
    button_stop.clicked.connect(() => { mpv_stop_playback(FIFO, OUTPUT); headerbar.set_title(NAME); });
    button_volume.value_changed.connect(volume_level_changed);

    set_button_size_relief_focus(button_restart);
    set_button_size_relief_focus(button_pause);
    set_button_size_relief_focus(button_rewind);
    set_button_size_relief_focus(button_forward);
    set_button_size_relief_focus(button_stop);
    set_button_size_relief_focus(button_volume);

    var label1 = new Gtk.Label("");
    var label2 = new Gtk.Label("");
    
    buttons_grid = new Gtk.Grid();
    buttons_grid.attach(button_restart, 0, 0, 1, 1); 
    buttons_grid.attach(label1,         1, 0, 2, 1); 
    buttons_grid.attach(button_pause,   3, 0, 1, 1);
    buttons_grid.attach(button_rewind,  4, 0, 1, 1);
    buttons_grid.attach(button_forward, 5, 0, 1, 1);
    buttons_grid.attach(button_stop,    6, 0, 1, 1); 
    buttons_grid.attach(label2,         7, 0, 2, 1); 
    buttons_grid.attach(button_volume,  9, 0, 1, 1); 
    
    buttons_grid.set_column_spacing(5);
    buttons_grid.set_border_width(5);
    buttons_grid.set_row_homogeneous(true);
    buttons_grid.set_column_homogeneous(true);
    
    var grid = new Gtk.Grid();
    grid.attach(drawing_area, 0, 0, 1, 1);
    grid.attach(buttons_grid,  0, 1, 1, 1);    
    
    context_menu = new Gtk.Menu();
    add_popup_menu(context_menu);
    
    var menuitem_about = new Gtk.MenuItem.with_label(_("About"));
    menuitem_about.activate.connect(about_dialog);
    
    var menu = new Gtk.Menu();
    menu.append(menuitem_about);
    menu.show_all();
    
    var menubutton = new Gtk.MenuButton();
    menubutton.valign = Gtk.Align.CENTER;
    menubutton.set_popup(menu);
    menubutton.set_image(new Gtk.Image.from_icon_name("emblem-system-symbolic", Gtk.IconSize.MENU));
    
    headerbar = new Gtk.HeaderBar();
    headerbar.set_show_close_button(true);
    headerbar.set_title(NAME);
    headerbar.pack_end(menubutton);
    
    window = new Gtk.Window();
    window.set_titlebar(headerbar);
    window.add(grid);
    window.show_all();
    window.set_icon_name(ICON);
    window.destroy.connect(() => { mpv_stop_playback(FIFO, OUTPUT); Gtk.main_quit();});
    window.key_press_event.connect(keyboard_events);
    Gtk.drag_dest_set(grid, Gtk.DestDefaults.ALL, targets, Gdk.DragAction.COPY);
    grid.drag_data_received.connect(on_drag_data_received);
    
    var drawing_area_window = (Gdk.X11.Window)drawing_area.get_window();
    xid = (long)drawing_area_window.get_xid();
  }
  
  private void set_button_size_relief_focus(Gtk.Button button_name)
  {
    button_name.set_relief(Gtk.ReliefStyle.NONE);
    button_name.set_can_focus(false);
  } 
  
  // Context menu
  private void add_popup_menu(Gtk.Menu menu)
  {
    // Top level
    var menuitem_open_file = new Gtk.MenuItem.with_label(_("Open"));
    var menuitem_play_url = new Gtk.MenuItem.with_label(_("Play URL"));
    var menuitem_subtitle = new Gtk.MenuItem.with_label(_("Subtitle"));
    var menuitem_aspect = new Gtk.MenuItem.with_label(_("Aspect ratio"));
    
    menuitem_open_file.activate.connect(open_file);
    menuitem_play_url.activate.connect(play_url);

    // Subtitles submenu
    var menuitem_subtitle_select = new Gtk.MenuItem.with_label(_("Select file"));
    var menuitem_subtitle_increase = new Gtk.MenuItem.with_label(_("Increase size"));
    var menuitem_subtitle_decrease = new Gtk.MenuItem.with_label(_("Decrease size"));
    
    menuitem_subtitle_select.activate.connect(select_subtitle_dialog);
    menuitem_subtitle_increase.activate.connect(() => { mpv_send_command(FIFO, "add sub-scale +0.5"); });
    menuitem_subtitle_decrease.activate.connect(() => { mpv_send_command(FIFO, "add sub-scale -0.5"); });

    var menuitem_subtitle_submenu = new Gtk.Menu();
    menuitem_subtitle_submenu.add(menuitem_subtitle_select);
    menuitem_subtitle_submenu.add(menuitem_subtitle_increase);
    menuitem_subtitle_submenu.add(menuitem_subtitle_decrease);
    menuitem_subtitle.set_submenu(menuitem_subtitle_submenu);

    // Aspect ratio submenu
    var menuitem_aspect_43 = new Gtk.MenuItem.with_label("4:3");
    var menuitem_aspect_169 = new Gtk.MenuItem.with_label("16:9");
    var menuitem_aspect_54 = new Gtk.MenuItem.with_label("5:4");
    var menuitem_aspect_11 = new Gtk.MenuItem.with_label("1:1");
    
    menuitem_aspect_43.activate.connect(() => { mpv_send_command(FIFO, "set aspect 1.333333"); });
    menuitem_aspect_169.activate.connect(() => { mpv_send_command(FIFO, "set aspect 1.777778"); });
    menuitem_aspect_54.activate.connect(() => { mpv_send_command(FIFO, "set aspect 1.25"); });
    menuitem_aspect_11.activate.connect(() => { mpv_send_command(FIFO, "set aspect 1"); });
    
    var menuitem_aspect_submenu = new Gtk.Menu();
    menuitem_aspect_submenu.add(menuitem_aspect_43);
    menuitem_aspect_submenu.add(menuitem_aspect_169);
    menuitem_aspect_submenu.add(menuitem_aspect_54);
    menuitem_aspect_submenu.add(menuitem_aspect_11);
    menuitem_aspect.set_submenu(menuitem_aspect_submenu);
    
    menuitem_open_file.show();
    menuitem_play_url.show();
    menuitem_subtitle.show();
    menuitem_subtitle_select.show();
    menuitem_subtitle_increase.show();
    menuitem_subtitle_decrease.show();
    menuitem_aspect.show();
    menuitem_aspect_43.show();
    menuitem_aspect_169.show();
    menuitem_aspect_54.show();
    menuitem_aspect_11.show();
    
    context_menu.append(menuitem_open_file);
    context_menu.append(menuitem_play_url);
    context_menu.append(menuitem_subtitle);
    context_menu.append(menuitem_aspect);
  }
  
  private void open_file()
  {
   var dialog = new Gtk.FileChooserDialog(_("Open File..."), window, Gtk.FileChooserAction.OPEN,
                                        "gtk-cancel", Gtk.ResponseType.CANCEL,
                                        "gtk-open", Gtk.ResponseType.ACCEPT);
   var filter = new Gtk.FileFilter();
   filter.set_filter_name(_("All Media Files"));
   filter.add_mime_type("audio/*");
   filter.add_mime_type("video/*");
   filter.add_mime_type("application/x-matroska");
   filter.add_mime_type("image/gif");
   dialog.add_filter(filter);
   dialog.set_transient_for(window);
   dialog.set_select_multiple(false);
   if (file != null)
   {
     dialog.set_current_folder(Path.get_dirname(file));
   }
   if (dialog.run() == Gtk.ResponseType.ACCEPT)
   {
     file = dialog.get_filename();
     gmp_video_start_playback();
   }
   dialog.destroy();
  }

  private void select_subtitle_dialog()
  {
    var dialog = new Gtk.FileChooserDialog(_("Select subtitle..."), window, Gtk.FileChooserAction.OPEN,
                                         "gtk-cancel", Gtk.ResponseType.CANCEL,
                                         "gtk-open", Gtk.ResponseType.ACCEPT);
    var filter = new Gtk.FileFilter();
    filter.set_filter_name("Subtitle Files");
    filter.add_mime_type("application/x-subrip");
    filter.add_mime_type("text/x-microdvd");
    dialog.add_filter(filter);
    dialog.set_transient_for(window);
    dialog.set_select_multiple(false);
    if (file != null)
    {
      dialog.set_current_folder(Path.get_dirname(file));
    }
    if (dialog.run() == Gtk.ResponseType.ACCEPT)
    {
      subtitle_file = dialog.get_filename();
      mpv_send_command(FIFO, "sub_add \"%s\"".printf(subtitle_file));
      mpv_send_command(FIFO, "cycle sub 0");
    }
    dialog.destroy();
  }

  private void full_screen_switch()
  {
    window.fullscreen();
    var invisible_cursor = new Gdk.Cursor(Gdk.CursorType.BLANK_CURSOR);
    Gdk.Window w = window.get_window();
    w.set_cursor(invisible_cursor);
    buttons_grid.hide();
  }
  
  private void full_screen_exit()
  {  
    window.unfullscreen();
    Gdk.Window w = window.get_window();
    w.set_cursor(null);
    buttons_grid.show();
  }
  
  private void volume_level_changed()
  {
    double level = button_volume.get_value() * 100;
    mpv_send_command(FIFO, "no-osd set volume %s".printf(level.to_string()));
  }
  
  // Keyboard shortcuts
  private bool keyboard_events(Gdk.EventKey event)
  {
    string key = Gdk.keyval_name(event.keyval);
    if ((window.get_window().get_state() & Gdk.WindowState.FULLSCREEN) != 0)
    {
      if(key=="Escape")
      {
        full_screen_exit();
      }
    }

    if (key=="F11")
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

    if(key=="space")
    {
      mpv_send_command(FIFO, "pause");
    }
  
    if(key=="Right")
    {
      mpv_send_command(FIFO, "seek +15");
    }  
      
    if(key=="Left")
    {
      mpv_send_command(FIFO, "seek -15");
    }
    
    if(key=="Page_Up")
    {
      mpv_send_command(FIFO, "seek -120");
    }  
      
    if(key=="Page_Down")
    {
      mpv_send_command(FIFO, "seek +120");
    }  
      
    return false;
  } 
  
  // Mouse EventButton Press
  private bool mouse_button_press_events(Gdk.EventButton event)
  {
    if (event.button == 3)
    {
      context_menu.select_first(false);
      context_menu.popup(null, null, null, event.button, event.time);
    }

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
    return false;
  }
  
  // Mouse EventButton Scroll
  private bool mouse_button_scroll_events(Gdk.EventScroll event)
  {
    if (event.direction == Gdk.ScrollDirection.UP)
    {
      mpv_send_command(FIFO, "seek +15");
    }
    if (event.direction == Gdk.ScrollDirection.DOWN)
    {
      mpv_send_command(FIFO, "seek -15");
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
      gmp_video_start_playback();
    }
    Gtk.drag_finish(drag_context, true, false, time);
  }
  
  private void play_url()
  {
    var play_url_dialog = new Gtk.Dialog();
    play_url_dialog.set_title(_("Open URL"));
    play_url_dialog.set_border_width(5);
    play_url_dialog.set_property("skip-taskbar-hint", true);
    play_url_dialog.set_transient_for(window);
    play_url_dialog.set_resizable(false);
    
    var play_url_label = new Gtk.Label(_("Open URL"));
    var play_url_entry = new Gtk.Entry();
    play_url_entry.set_size_request(410, 0);
    play_url_entry.activate.connect(() => { gmp_video_start_playback(); });
    
    var grid = new Gtk.Grid();
    grid.attach(play_url_label, 0, 0, 1, 1);
    grid.attach(play_url_entry, 1, 0, 5, 1);
    grid.set_column_spacing(25);
    grid.set_column_homogeneous(true);

    var content = play_url_dialog.get_content_area() as Gtk.Box;
    content.pack_start(grid, true, true, 10);

    play_url_dialog.add_button(_("Play"), Gtk.ResponseType.OK);
    play_url_dialog.add_button(_("Close"), Gtk.ResponseType.CLOSE);
    play_url_dialog.set_default_response(Gtk.ResponseType.OK);
    play_url_dialog.show_all();
    if (play_url_dialog.run() == Gtk.ResponseType.OK)
    {
      file = play_url_entry.get_text();
      gmp_video_start_playback();
    }
    play_url_dialog.destroy();
  }

  private void gmp_video_start_playback()
  {
    var basename = Path.get_basename(file);
    mpv_stop_playback(FIFO, OUTPUT);
    mpv_video_with_subtitles(video_mode, subtitle_color, subtitle_scale, subtitle_fuzziness, xid, FIFO, file, OUTPUT);
    button_volume.set_value(1.00);
    headerbar.set_title("%s - %s".printf(NAME, basename));
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
  
    // Start program
  private void run(string[] args)
  {
    if (args.length >= 2)
    {
      file = args[1];
      gmp_video_start_playback();
    }
  }
  
  public static int main (string[] args)
  {
    Gtk.init(ref args);
    var GmpVideo = new Program();
    GmpVideo.run(args);
    Gtk.main();
    return 0;
  }
}
