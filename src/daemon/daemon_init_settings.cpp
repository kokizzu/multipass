/*
 * Copyright (C) 2017-2021 Canonical, Ltd.
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; version 3.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 */

#include "daemon_init_settings.h"

#include <multipass/constants.h>
#include <multipass/platform.h>
#include <multipass/settings/basic_setting_spec.h>
#include <multipass/settings/bool_setting_spec.h>
#include <multipass/settings/dynamic_setting_spec.h>
#include <multipass/settings/persistent_settings_handler.h>
#include <multipass/settings/settings.h>
#include <multipass/utils.h>

#include <QCoreApplication>
#include <QFileSystemWatcher>
#include <QObject>

namespace mp = multipass;

namespace
{
constexpr const int settings_changed_code = 42;

/*
 * We make up our own file names to:
 *   a) avoid unknown org/domain in path;
 *   b) write daemon config to a central location (rather than user-dependent)
 * Example: /root/.config/multipassd/multipassd.conf
 */
QString persistent_settings_filename()
{
    static const auto file_pattern = QStringLiteral("%2%1").arg(mp::settings_extension);
    static const auto daemon_dir_path = QDir{MP_PLATFORM.daemon_config_home()}; // temporary, replace w/ AppConfigLoc
    static const auto path = daemon_dir_path.absoluteFilePath(file_pattern.arg(mp::daemon_name));

    return path;
}

QString driver_interpreter(const QString& val)
{
    if (!MP_PLATFORM.is_backend_supported(val))
        throw mp::InvalidSettingException(mp::driver_key, val, "Invalid driver");

    return val;
}

} // namespace

void mp::daemon::monitor_and_quit_on_settings_change() // temporary
{
    static const auto filename = persistent_settings_filename();
    mp::utils::check_and_create_config_file(filename); // create if not there

    static QFileSystemWatcher monitor{{filename}};
    QObject::connect(&monitor, &QFileSystemWatcher::fileChanged, [] { QCoreApplication::exit(settings_changed_code); });
}

void mp::daemon::register_global_settings_handlers()
{
    auto settings = MP_PLATFORM.extra_daemon_settings(); // platform settings override inserts with the same key below
    settings.insert(std::make_unique<BasicSettingSpec>(bridged_interface_key, ""));
    settings.insert(std::make_unique<BoolSettingSpec>(mounts_key, MP_PLATFORM.default_privileged_mounts()));
    settings.insert(std::make_unique<DynamicSettingSpec>(driver_key, MP_PLATFORM.default_driver(), driver_interpreter));

    MP_SETTINGS.register_handler(
        std::make_unique<PersistentSettingsHandler>(persistent_settings_filename(), std::move(settings)));
}