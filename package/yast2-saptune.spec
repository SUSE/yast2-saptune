#
# spec file for package yast2-saptune
#
# Copyright (c) 2016-2019 SUSE LLC.
#
# All modifications and additions to the file contributed by third parties
# remain the property of their copyright owners, unless otherwise agreed
# upon. The license for this file, and modifications and additions to the
# file, is the same license as for the pristine package itself (unless the
# license for the pristine package is not an Open Source License, in which
# case the license is the MIT License). An "Open Source License" is a
# license that conforms to the Open Source Definition (Version 1.9)
# published by the Open Source Initiative.

# Please submit bugfixes or comments via http://bugs.opensuse.org/
#

Name:           yast2-saptune
Version:        1.3
Release:        0
License:        GPL-3.0
Summary:        An alternative and minimal interface for configuring saptune
Url:            https://www.suse.com/products/sles-for-sap
Group:          System/YaST
Source:         %{name}-%{version}.tar.bz2
BuildArch:      noarch
BuildRequires:  yast2 yast2-ruby-bindings yast2-devtools
BuildRequires:  rubygem(yast-rake) rubygem(rspec)
Requires:       yast2

%description
This is a configuration editor for saptune - the comprehensive tuning management
tool for SAP solutions.
It works in both stand-alone and AutoYast mode to automatically configure
saptune and control its state.

%prep
%setup -q

%check
rake test:unit

%build

%install
rake install DESTDIR="%{buildroot}"

%files
%defattr(-,root,root)
%doc %yast_docdir
%yast_desktopdir/saptune*
%yast_clientdir/saptune*
%yast_libdir/saptune*

%changelog
