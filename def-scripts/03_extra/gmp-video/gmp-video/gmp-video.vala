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

private class Program : Gtk.Application
{
  const string NAME        = "GMP Video";
  const string VERSION     = "1.1.5";
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
  Gtk.ApplicationWindow window;
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
  bool playing;

  private const GLib.ActionEntry[] action_entries =
  {
    { "about",              action_about              },
    { "quit",               action_quit               },
    { "open-file",          action_open_file          },
    { "open-url",           action_open_url           },
    { "full-screen-exit",   action_full_screen_exit   },
    { "full-screen-toggle", action_full_screen_toggle },
    { "pause",              action_pause              },
    { "seek-plus-15",       action_seek_plus_15       },
    { "seek-minus-15",      action_seek_minus_15      },
    { "seek-plus-120",      action_seek_plus_120      },
    { "seek-minus-120",     action_seek_minus_120     }
  };

  private Program()
  {
    Object(application_id: "org.alphaos.gmp-video", flags: ApplicationFlags.HANDLES_OPEN);
    add_action_entries(action_entries, this);
  }

  public override void startup()
  {
    base.startup();

    var menu = new Menu();
    menu.append(_("About"),     "app.about");
    menu.append(_("Quit"),      "app.quit");

    set_app_menu(menu);

    add_accelerator("<Control>O", "app.open-file", null);
    add_accelerator("<Control>U", "app.open-url", null);
    add_accelerator("Escape", "app.full-screen-exit", null);
    add_accelerator("F11", "app.full-screen-toggle", null);
    add_accelerator("space", "app.pause", null);
    add_accelerator("Right", "app.seek-plus-15", null);
    add_accelerator("Left", "app.seek-minus-15", null);
    add_accelerator("Page_Up", "app.seek-plus-120", null);
    add_accelerator("Page_Down", "app.seek-minus-120", null);
    
    settings = new GLib.Settings("org.alphaos.gmp-video.preferences");
    drawing_area_width = settings.get_int("drawing-area-width");
    drawing_area_height = settings.get_int("drawing-area-height");
    video_mode = settings.get_string("video-mode");
    subtitle_color = settings.get_string("subtitle-color");
    subtitle_scale = settings.get_double("subtitle-scale");
    subtitle_fuzziness = settings.get_string("subtitle-fuzziness");

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
    button_pause = new Gtk.Button();
    button_pause_set_image();
    button_rewind = new Gtk.Button.from_icon_name("media-skip-backward-symbolic", Gtk.IconSize.LARGE_TOOLBAR);
    button_forward = new Gtk.Button.from_icon_name("media-skip-forward-symbolic", Gtk.IconSize.LARGE_TOOLBAR);
    button_stop = new Gtk.Button.from_icon_name("media-playback-stop-symbolic", Gtk.IconSize.LARGE_TOOLBAR);
    button_volume = new Gtk.VolumeButton();
    button_volume.use_symbolic = true;
    button_volume.set_value(1.00);

    button_restart.clicked.connect(() => { gmp_video_start_playback(); });
    button_pause.clicked.connect(action_pause);
    button_rewind.clicked.connect(action_seek_minus_15);
    button_forward.clicked.connect(action_seek_plus_15);
    button_stop.clicked.connect(() => { mpv_stop_playback(FIFO, OUTPUT); headerbar.set_title(NAME); playing = false; button_pause_set_image(); });
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
    
    var gear_menu = new Gtk.Menu();
    add_popup_menu(gear_menu);
    
    var menubutton = new Gtk.MenuButton();
    menubutton.valign = Gtk.Align.CENTER;
    menubutton.set_popup(gear_menu);
    menubutton.set_image(new Gtk.Image.from_icon_name("emblem-system-symbolic", Gtk.IconSize.MENU));

    headerbar = new Gtk.HeaderBar();
    headerbar.set_show_close_button(true);
    headerbar.set_title(NAME);
    headerbar.pack_end(menubutton);
    
    window = new Gtk.ApplicationWindow(this);
    window.set_titlebar(headerbar);
    window.add(grid);
    window.set_icon_name(ICON);
    window.show_all();
    window.delete_event.connect(() => { action_quit(); return true; });

    Gtk.drag_dest_set(grid, Gtk.DestDefaults.ALL, targets, Gdk.DragAction.COPY);
    grid.drag_data_received.connect(on_drag_data_received);
    
    var drawing_area_window = (Gdk.X11.Window)drawing_area.get_window();
    xid = (long)drawing_area_window.get_xid();
  }

  public override void activate() 
  {
    window.present();
  }
  
  public override void open(File[] files, string hint)
  {
    window.present();
    foreach (File f in files)
    {
      file = f.get_uri();
    }
    gmp_video_start_playback();
  }  

  private void set_button_size_relief_focus(Gtk.Button button_name)
  {
    button_name.set_relief(Gtk.ReliefStyle.NONE);
    button_name.set_can_focus(false);
  }
  
  private void button_pause_set_image()
  {
    Gtk.Image image_play_pause;
    if (playing == true)
    {
      image_play_pause = new Gtk.Image.from_icon_name("media-playback-pause-symbolic", Gtk.IconSize.LARGE_TOOLBAR);
    }
    else
    {
      image_play_pause = new Gtk.Image.from_icon_name("media-playback-start-symbolic", Gtk.IconSize.LARGE_TOOLBAR);
    }
    button_pause.set_image(image_play_pause);
    button_pause.set_always_show_image(true);
  }
  
  // Context menu
  private void add_popup_menu(Gtk.Menu menu)
  {
    // Top level
    var menuitem_open = new Gtk.MenuItem.with_label(_("Open"));
    var menuitem_subtitle = new Gtk.MenuItem.with_label(_("Subtitle"));
    var menuitem_aspect = new Gtk.MenuItem.with_label(_("Aspect ratio"));
    var menuitem_speed = new Gtk.MenuItem.with_label(_("Speed"));
    var menuitem_zoom = new Gtk.MenuItem.with_label(_("Zoom"));
    
    // Open submenu
    var menuitem_open_file = new Gtk.MenuItem.with_label(_("File"));
    var menuitem_open_url = new Gtk.MenuItem.with_label(_("URL"));

    menuitem_open_file.activate.connect(action_open_file);
    menuitem_open_url.activate.connect(action_open_url);
    
    var menuitem_open_submenu = new Gtk.Menu();
    menuitem_open_submenu.add(menuitem_open_file);
    menuitem_open_submenu.add(menuitem_open_url);
    menuitem_open.set_submenu(menuitem_open_submenu);

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
    var menuitem_aspect_auto = new Gtk.MenuItem.with_label(_("Auto"));
    var menuitem_aspect_43 = new Gtk.MenuItem.with_label("4:3");
    var menuitem_aspect_169 = new Gtk.MenuItem.with_label("16:9");
    var menuitem_aspect_54 = new Gtk.MenuItem.with_label("5:4");
    var menuitem_aspect_11 = new Gtk.MenuItem.with_label("1:1");
    
    menuitem_aspect_auto.activate.connect(() => { mpv_send_command(FIFO, "set aspect 0"); });
    menuitem_aspect_43.activate.connect(() => { mpv_send_command(FIFO, "set aspect 1.333333"); });
    menuitem_aspect_169.activate.connect(() => { mpv_send_command(FIFO, "set aspect 1.777778"); });
    menuitem_aspect_54.activate.connect(() => { mpv_send_command(FIFO, "set aspect 1.25"); });
    menuitem_aspect_11.activate.connect(() => { mpv_send_command(FIFO, "set aspect 1"); });
    
    var menuitem_aspect_submenu = new Gtk.Menu();
    menuitem_aspect_submenu.add(menuitem_aspect_auto);
    menuitem_aspect_submenu.add(menuitem_aspect_43);
    menuitem_aspect_submenu.add(menuitem_aspect_169);
    menuitem_aspect_submenu.add(menuitem_aspect_54);
    menuitem_aspect_submenu.add(menuitem_aspect_11);
    menuitem_aspect.set_submenu(menuitem_aspect_submenu);
    
    // Speed submenu
    var menuitem_speed_auto = new Gtk.MenuItem.with_label(_("Auto"));
    var menuitem_speed_18 = new Gtk.MenuItem.with_label("0.18");
    var menuitem_speed_30 = new Gtk.MenuItem.with_label("0.30");
    var menuitem_speed_50 = new Gtk.MenuItem.with_label("0.50");
    var menuitem_speed_75 = new Gtk.MenuItem.with_label("0.75");
    var menuitem_speed_150 = new Gtk.MenuItem.with_label("1.50");
    var menuitem_speed_200 = new Gtk.MenuItem.with_label("2.00");
    var menuitem_speed_300 = new Gtk.MenuItem.with_label("3.00");
    var menuitem_speed_400 = new Gtk.MenuItem.with_label("4.00");

    menuitem_speed_auto.activate.connect(() => { mpv_send_command(FIFO, "set speed 1.00"); });
    menuitem_speed_18.activate.connect(() => { mpv_send_command(FIFO, "set speed 0.18"); });
    menuitem_speed_30.activate.connect(() => { mpv_send_command(FIFO, "set speed 0.30"); });
    menuitem_speed_50.activate.connect(() => { mpv_send_command(FIFO, "set speed 0.50"); });
    menuitem_speed_75.activate.connect(() => { mpv_send_command(FIFO, "set speed 0.75"); });
    menuitem_speed_150.activate.connect(() => { mpv_send_command(FIFO, "set speed 1.50"); });
    menuitem_speed_200.activate.connect(() => { mpv_send_command(FIFO, "set speed 2.00"); });
    menuitem_speed_300.activate.connect(() => { mpv_send_command(FIFO, "set speed 3.00"); });
    menuitem_speed_400.activate.connect(() => { mpv_send_command(FIFO, "set speed 4.00"); });
    
    var menuitem_speed_submenu = new Gtk.Menu();
    menuitem_speed_submenu.add(menuitem_speed_auto);
    menuitem_speed_submenu.add(menuitem_speed_18);
    menuitem_speed_submenu.add(menuitem_speed_30);
    menuitem_speed_submenu.add(menuitem_speed_50);
    menuitem_speed_submenu.add(menuitem_speed_75);
    menuitem_speed_submenu.add(menuitem_speed_150);
    menuitem_speed_submenu.add(menuitem_speed_200);
    menuitem_speed_submenu.add(menuitem_speed_300);
    menuitem_speed_submenu.add(menuitem_speed_400);
    menuitem_speed.set_submenu(menuitem_speed_submenu);

    // Zoom submenu
    var menuitem_zoom_auto = new Gtk.MenuItem.with_label(_("Auto"));
    var menuitem_zoom_10 = new Gtk.MenuItem.with_label(_("Smaller 10%"));
    var menuitem_zoom_25 = new Gtk.MenuItem.with_label(_("Smaller 25%"));
    var menuitem_zoom_33 = new Gtk.MenuItem.with_label(_("Smaller 33%"));
    var menuitem_zoom_50 = new Gtk.MenuItem.with_label(_("Smaller 50%"));
    var menuitem_zoom_2x = new Gtk.MenuItem.with_label(_("Double size"));
    
    menuitem_zoom_auto.activate.connect(() => { mpv_send_command(FIFO, "set video-zoom 0"); });
    menuitem_zoom_10.activate.connect(() => { mpv_send_command(FIFO, "set video-zoom -0.10"); });
    menuitem_zoom_25.activate.connect(() => { mpv_send_command(FIFO, "set video-zoom -0.25"); });
    menuitem_zoom_33.activate.connect(() => { mpv_send_command(FIFO, "set video-zoom -0.33"); });
    menuitem_zoom_50.activate.connect(() => { mpv_send_command(FIFO, "set video-zoom -0.50"); });
    menuitem_zoom_2x.activate.connect(() => { mpv_send_command(FIFO, "set video-zoom 1.00"); });
    
    var menuitem_zoom_submenu = new Gtk.Menu();
    menuitem_zoom_submenu.add(menuitem_zoom_auto);
    menuitem_zoom_submenu.add(menuitem_zoom_10);
    menuitem_zoom_submenu.add(menuitem_zoom_25);
    menuitem_zoom_submenu.add(menuitem_zoom_33);
    menuitem_zoom_submenu.add(menuitem_zoom_50);
    menuitem_zoom_submenu.add(menuitem_zoom_2x);
    menuitem_zoom.set_submenu(menuitem_zoom_submenu);
    
    menu.append(menuitem_open);
    menu.append(menuitem_subtitle);
    menu.append(menuitem_aspect);
    menu.append(menuitem_speed);
    menu.append(menuitem_zoom);
    menu.show_all();
  }
  
  private void action_open_file()
  {
   var dialog = new Gtk.FileChooserDialog(_("Open file"), window, Gtk.FileChooserAction.OPEN,
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
    var dialog = new Gtk.FileChooserDialog(_("Select subtitle"), window, Gtk.FileChooserAction.OPEN,
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
  
  private void volume_level_changed()
  {
    double level = button_volume.get_value() * 100;
    mpv_send_command(FIFO, "no-osd set volume %s".printf(level.to_string()));
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
      action_full_screen_toggle();
    }
    return false;
  }
  
  // Mouse EventButton Scroll
  private bool mouse_button_scroll_events(Gdk.EventScroll event)
  {
    if (event.direction == Gdk.ScrollDirection.UP)
    {
      action_seek_plus_15();
    }
    if (event.direction == Gdk.ScrollDirection.DOWN)
    {
      action_seek_minus_15();
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
  
  private void action_open_url()
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
    playing = true;
    button_pause_set_image();
  }

  private void action_full_screen_exit()
  {
    window.unfullscreen();
    Gdk.Window w = window.get_window();
    w.set_cursor(null);
    buttons_grid.show();
  }
  
  private void action_full_screen_toggle()
  {
    if ((window.get_window().get_state() & Gdk.WindowState.FULLSCREEN) != 0)
    {
      window.unfullscreen();
      Gdk.Window w = window.get_window();
      w.set_cursor(null);
      buttons_grid.show();
    }
    else
    {
      window.fullscreen();
      var invisible_cursor = new Gdk.Cursor(Gdk.CursorType.BLANK_CURSOR);
      Gdk.Window w = window.get_window();
      w.set_cursor(invisible_cursor);
      buttons_grid.hide();
    }
  }
  
  private void action_pause()
  {
    mpv_send_command(FIFO, "cycle pause");
    if (playing == true)
    {
      playing = false;
    }
    else
    {
      playing = true;
    }
    button_pause_set_image();
  }
  
  private void action_seek_plus_15()
  {
    mpv_send_command(FIFO, "seek +15");
  }
  
  private void action_seek_minus_15()
  {
    mpv_send_command(FIFO, "seek -15");
  }
  
  private void action_seek_plus_120()
  {
    mpv_send_command(FIFO, "seek +120");
  }
  
  private void action_seek_minus_120()
  {
    mpv_send_command(FIFO, "seek -120");
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
    mpv_stop_playback(FIFO, OUTPUT);
    quit();
  }

  private static int main (string[] args)
  {
    Program app = new Program();
    return app.run(args);
  }
}
