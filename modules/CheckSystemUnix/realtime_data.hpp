#pragma once
#include <list>

#include <boost/filesystem/path.hpp>
#include "filter.hpp"
#include "realtime_thread.hpp"
/*
namespace check_cpu_filter {
	struct runtime_data {

		typedef check_cpu_filter::filter filter_type;
		typedef pdh_thread* transient_data_type;

		struct container {
			std::string alias;
			long time;
		};

		std::list<container> checks;

		void boot() {}
		void touch(boost::posix_time::ptime now) {}
		bool has_changed(transient_data_type) const { return true; }
		bool process_item(filter_type &filter, transient_data_type);
		void add(const std::string &time);
	};

}


namespace check_mem_filter {
	struct runtime_data {

		typedef check_mem_filter::filter filter_type;
		typedef CheckMemory* transient_data_type;

		std::list<std::string> checks;

		void boot() {}
		void touch(boost::posix_time::ptime now) {}
		bool has_changed(transient_data_type) const { return true; }
		bool process_item(filter_type &filter, transient_data_type);
		void add(const std::string &data);
	};

}
*/
